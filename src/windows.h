#pragma once

#include <stdint.h>

#ifndef __cplusplus
typedef unsigned char bool;
#endif

#define true 1
#define false 0

#ifdef __cplusplus
extern "C" {
#endif

#ifdef CW_BUILDING_DLL
#define CW_EXPORT __declspec(dllexport)
#else
#define CW_EXPORT __declspec(dllimport)
#endif

#ifdef __cplusplus
}
#endif