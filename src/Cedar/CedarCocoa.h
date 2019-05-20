//
//  SwiftHeader.h
//  libsoftether
//
//  Created by Gentoli on 2019-02-03.
//

#ifndef CedarCocoa
#define CedarCocoa

// Replace function


// Overried function
// WebUI.c
#pragma weak WuNewWebUI

// Client.c
#pragma weak CiInitConfiguration

// IPC.c
#pragma weak IPCRecvL2
#pragma weak IPCSendL2
#pragma weak NewIPCByParam
#pragma weak IPCDhcpSetConditionalUserClass
//#pragma weak FlushTubeFlushList
//#pragma weak AddInterrupt


void IPCPutL3(void*,void*,unsigned int);

#endif // CedarCocoa
