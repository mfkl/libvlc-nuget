#include "pch.h"
#include "libaccess_winrt_plugin.h"

#include <vlc_access.h>
#include <vlc_input.h>
#include <vlc_charset.h>


using namespace winrt;
using namespace Windows::Storage;
using namespace Windows::Storage::Streams;
using namespace Windows::ApplicationModel::DataTransfer;
using namespace Windows::Foundation;


/*****************************************************************************
* Module descriptor
*****************************************************************************/

vlc_module_begin()
set_shortname(N_("WinRTInput"))
set_description(N_("WinRT input"))
set_category(CAT_INPUT)
set_subcategory(SUBCAT_INPUT_ACCESS)
set_capability("access", 80)
add_shortcut("winrt", "file")
set_callbacks(&Open, &Close)
vlc_module_end()


struct access_sys_t
{
	IRandomAccessStream read_stream;
	DataReader data_reader;
	uint64_t               i_pos;
	bool                   b_eof;
};

namespace
{
	bool is_token_valid(const hstring& future_access_token) {
		// TODO: validate token
		// auto charBegin = future_access_token[0];
		// auto charEnd = future_access_token[future_access_token.size() - 1];
		// return !((charBegin != '{') || ((charEnd != '}') || future_access_token->Length() < 32));
		return true;
	}

	/*****************************************************************************
	* Local prototypes
	*****************************************************************************/

	/**
	 * Handles the file opening
	 */
	IAsyncAction open_file_from_path_async(access_sys_t* p_sys, const hstring& path)
	{
		auto file = co_await StorageFile::GetFileFromPathAsync(path);
		auto stream = co_await file.OpenReadAsync();
		p_sys->read_stream = stream;
		p_sys->data_reader = DataReader(stream);
	}

	int open_file_from_path(access_sys_t* p_sys, const hstring& path)
	{
		try
		{
			open_file_from_path_async(p_sys, path).get();
			return VLC_SUCCESS;
		}
		catch (hresult_error const& ex)
		{
			OutputDebugString(ex.message().c_str());
			OutputDebugString(L"Failed to open file.");
			return VLC_EGENERIC;
		}
	}

	IAsyncAction open_file_from_token_async(access_sys_t* p_sys, const hstring& token)
	{
		auto file = co_await SharedStorageAccessManager::RedeemTokenForFileAsync(token);
		auto stream = co_await file.OpenReadAsync();
		p_sys->read_stream = stream;
		p_sys->data_reader = DataReader(stream);
	}

	int open_file_from_token(access_sys_t* p_sys, const hstring& token)
	{
		try
		{
			open_file_from_token_async(p_sys, token).get();
			return VLC_SUCCESS;
		}
		catch (hresult_error const& ex)
		{
			OutputDebugString(ex.message().c_str());
			OutputDebugString(L"Failed to open file.");
			return VLC_EGENERIC;
		}
	}

	IAsyncOperation<unsigned int> read_async(const DataReader& reader, array_view<uint8_t> buffer)
	{
		const auto bytes_loaded = co_await reader.LoadAsync(buffer.size());
		buffer = array_view(buffer.data(), bytes_loaded);
		reader.ReadBytes(buffer);
		co_return bytes_loaded;
	}

	/* */
	int seek(stream_t* access, uint64_t position)
	{
		access_sys_t* p_sys = static_cast<access_sys_t*>(access->p_sys);

		try
		{
			p_sys->read_stream.Seek(position);
			p_sys->i_pos = position;
			p_sys->b_eof = p_sys->read_stream.Position() >= p_sys->read_stream.Size();
		}
		catch (hresult_error const& ex)
		{
			OutputDebugString(ex.message().c_str());
			return VLC_EGENERIC;
		}

		return VLC_SUCCESS;
	}

	/* */
	int control(stream_t* access, int query, va_list args)
	{
		const auto p_sys = static_cast<access_sys_t*>(access->p_sys);

		VLC_UNUSED(access);
		switch (query)
		{
		case STREAM_CAN_FASTSEEK:
		case STREAM_CAN_PAUSE:
		case STREAM_CAN_SEEK:
		case STREAM_CAN_CONTROL_PACE: {
			bool* b = va_arg(args, bool*);
			*b = true;
			return VLC_SUCCESS;
		}

		case STREAM_GET_PTS_DELAY: {
			int64_t* d = va_arg(args, int64_t*);
			*d = DEFAULT_PTS_DELAY;
			return VLC_SUCCESS;
		}

		case STREAM_SET_PAUSE_STATE:
			return VLC_SUCCESS;

		case STREAM_GET_SIZE: {
			*va_arg(args, uint64_t*) = p_sys->read_stream.Size();
			return VLC_SUCCESS;
		}
		default:
			return VLC_EGENERIC;
		}
	}

	/* */
	ssize_t read(stream_t* access, void* buffer, size_t size)
	{
		if (buffer == nullptr)
		{
			if (seek(access, size) == VLC_SUCCESS)
				return size;
			return 0;
		}

		access_sys_t* p_sys = static_cast<access_sys_t*>(access->p_sys);

		unsigned int total_read;
		const auto buffer_view = array_view(static_cast<uint8_t*>(buffer), static_cast<uint32_t>(size));

		try
		{
			total_read = read_async(p_sys->data_reader, buffer_view).get(); /* block with wait since we're in a worker thread */
		}
		catch (hresult_error const& ex)
		{
			OutputDebugString(L"Failure while reading block\n");
			if (ex.code() == HRESULT_FROM_WIN32(ERROR_OPLOCK_HANDLE_CLOSED)) {
				if (open_file_from_path(p_sys, to_hstring(access->psz_location)) == VLC_SUCCESS) {
					p_sys->read_stream.Seek(p_sys->i_pos);
					return read(access, buffer, size);
				}
				OutputDebugString(L"Failed to reopen file\n");
			}
			return 0;
		}

		p_sys->i_pos += total_read;
		p_sys->b_eof = p_sys->read_stream.Position() >= p_sys->read_stream.Size();
		if (p_sys->b_eof) {
			OutputDebugString(L"End of file reached\n");
		}

		return total_read;
	}
}

int Open(vlc_object_t* object)
{
	stream_t* access = reinterpret_cast<stream_t*>(object);
	hstring access_token;
	int (*pf_open)(access_sys_t*, const hstring&);

	if (strncmp(access->psz_name, "winrt", 5) == 0) {
		access_token = to_hstring(access->psz_location);
		if (!is_token_valid(access_token))
			return VLC_EGENERIC;
		pf_open = open_file_from_token;
	}
	else if (strncmp(access->psz_name, "file", 4) == 0) {
		char* pos = strstr(access->psz_filepath, "winrt:\\\\");
		if (pos && strlen(pos) > 8) {
			access_token = to_hstring(pos + 8);
			if (!is_token_valid(access_token))
				return VLC_EGENERIC;
			pf_open = open_file_from_token;
		}
		else
		{
			pf_open = open_file_from_path;
			access_token = to_hstring(access->psz_filepath);
		}
	}
	else
		return VLC_EGENERIC;

	const auto p_sys = new(std::nothrow) access_sys_t{nullptr, nullptr, 0, false};
	access->p_sys = p_sys;
	if (p_sys == nullptr)
		return VLC_EGENERIC;

	p_sys->i_pos = 0;
	if (pf_open(p_sys, access_token) != VLC_SUCCESS) {
		OutputDebugStringW(L"Error opening file with Path");
		Close(object);
		return VLC_EGENERIC;
	}

	access->pf_read = &read;
	access->pf_seek = &seek;
	access->pf_control = &control;

	return VLC_SUCCESS;
}

/* */
void Close(vlc_object_t* object)
{
	stream_t* access = reinterpret_cast<stream_t*>(object);
	access_sys_t* p_sys = static_cast<access_sys_t*>(access->p_sys);
	if (p_sys->data_reader != nullptr) {
		p_sys->data_reader = nullptr;
	}
	if (p_sys->read_stream != nullptr) {
		p_sys->read_stream = nullptr;
	}
	delete p_sys;
}

