#pragma once

#ifndef MODULE_STRING
#define MODULE_STRING "access_winrt"
#endif

#ifdef _MSC_VER /* help visual studio compile vlc headers */
# define inline __inline
# define strdup _strdup
# define strcasecmp _stricmp
# define ssize_t SSIZE_T
# define N_(x) x
# define _(x) x
int poll(struct pollfd*, unsigned, int);
# define restrict __restrict
#endif

# define VLC_MODULE_COPYRIGHT "Copyright";
# define VLC_MODULE_LICENSE  VLC_LICENSE_LGPL_2_1_PLUS;

#include <vlc_common.h>
#include <vlc_plugin.h>


static int                    Open(vlc_object_t*);
static void                   Close(vlc_object_t*);
