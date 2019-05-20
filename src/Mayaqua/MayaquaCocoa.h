//
//  SwiftHeader.h
//  libsoftether
//
//  Created by Gentoli on 2019-02-03.
//

#ifndef MayaquaCocoa
#define MayaquaCocoa

#import <objc/objc.h>
#include "MayaType.h"

// Function Headers
void signEvent(char*,UINT);


// Replace function
#define system s_system
#define fputs(msg,pipe) s_fputs(#pipe,msg)
//#define setsockopt s_setsockopt
//#define close s_close
//#define socket(a,b,c) s_socket(a,b,c)
//#define read(a,b,c) s_read(a,b,c)
int s_socket(int,int,int);
int s_close(int);
int s_system(const char *);
int s_fputs(const char *, char *);
int s_setsockopt(int, int, int, const void *, socklen_t);
int s_read(int,void*,size_t);

// Overried function
// Network.c
#pragma weak Recv
#pragma weak StartSSLEx
#pragma weak UnixSelect
#pragma weak ConnectEx4
#pragma weak Send
#pragma weak NewCancel
#pragma weak ReleaseCancel
#pragma weak Cancel
#pragma weak signEvent

// Table.c
#pragma weak GetTableStr
#pragma weak GetTableUniStr

// FileIO.c
#pragma weak FileOpen

// Kernal.c
#pragma weak NewThreadNamed
#pragma weak WaitThreadInit
#pragma weak ReleaseThread
#pragma weak NoticeThreadInit

// Tick64.c
#pragma weak Tick64
#pragma weak TickHighres64

// Probe
#define    PROBE_STR(str)                signEvent(str,0);
#define    PROBE_DATA2(str, data, size)  signEvent(str,size);

#endif // MayaquaCocoa
