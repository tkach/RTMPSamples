
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdio.h>

#include <getopt.h>

#include <rtmp_sys.h>
#include <log.h>
#include <rtmp.h>


#import "RTMPStreamSender.h"

@interface RTMPStreamSender()

- (void)clean;

@end


@implementation RTMPStreamSender

- (id)initWithURL:(NSString *)urlParam {
   self = [super init];
   
   if (self) {
      url = urlParam;
   }
   
   return self;
}


- (void) clean {
	if (RTMP_IsConnected(&rtmp)) {
		RTMP_DeleteStream(&rtmp);
		RTMP_Close(&rtmp);
	}

	bOverrideBufferTime = FALSE;	// if the user specifies a buffer time override this is true
	
	// meta header and initial frame for the resume mode (they are read from the file and compared with
	// the stream we are trying to continue
	metaHeader = 0;
	nMetaHeaderSize = 0;
	
	initialFrameType = 0;	// tye: audio or video
	
	hostname = (AVal){ 0, 0 };
	playpath = (AVal){ 0, 0 };
	subscribepath = (AVal){ 0, 0 };
	port = -1;
	protocol = RTMP_PROTOCOL_UNDEFINED;
	retries = 0;
	bLiveStream = true;	// is it a live stream? then we can't seek/resume
	bHashes = FALSE;		// display byte counters not hashes by default
	
	dStartOffset = 0;	// seek position in non-live mode
	dStopOffset = 0;

	
	swfUrl = (AVal){ 0, 0 };
	tcUrl = (AVal){ 0, 0 };
	pageUrl = (AVal){ 0, 0 };
	app = (AVal){ 0, 0 };
	auth = (AVal){ 0, 0 };
	swfHash = (AVal){ 0, 0 };
	swfSize = 0;
	flashVer = (AVal){ 0, 0 };
	sockshost = (AVal){ 0, 0 };
}



- (void)connect {
   [self clean];
   
	started = NO;
   
	char *opt = (char*)[url UTF8String];
	int first = 1;
   
   
	RTMP_Init(&rtmp);
	AVal parsedHost, parsedApp, parsedPlaypath;
	unsigned int parsedPort = 0;
	int parsedProtocol = RTMP_PROTOCOL_UNDEFINED;
	
	if (!RTMP_ParseURL(opt, &parsedProtocol, &parsedHost, &parsedPort, &parsedPlaypath, &parsedApp))
	{
		RTMP_Log(RTMP_LOGWARNING, "Couldn't parse the specified url (%s)!", opt);
	}
	else
	{
		if (!hostname.av_len)
			hostname = parsedHost;
		if (port == -1)
			port = parsedPort;
		if (playpath.av_len == 0 && parsedPlaypath.av_len)
		{
			playpath = parsedPlaypath;
		}
		if (protocol == RTMP_PROTOCOL_UNDEFINED)
			protocol = parsedProtocol;
		if (app.av_len == 0 && parsedApp.av_len)
		{
         app = parsedApp;
		}
	}
	
	if (protocol == RTMP_PROTOCOL_UNDEFINED)
   {
		RTMP_Log(RTMP_LOGWARNING,
               "You haven't specified a protocol or rtmp url.");
		protocol = RTMP_PROTOCOL_RTMP;
   }
	if (port == -1)
   {
		RTMP_Log(RTMP_LOGWARNING,
               "You haven't specified a port or rtmp url, using default port 1935");
		port = 0;
   }
	if (port == 0)
   {
		if (protocol & RTMP_FEATURE_SSL)
			port = 443;
		else if (protocol & RTMP_FEATURE_HTTP)
			port = 80;
		else
			port = 1935;
   }
	
	if (tcUrl.av_len == 0)
   {
		char str[512] = { 0 };
		
		tcUrl.av_len = snprintf(str, 511, "%s://%.*s:%d/%.*s",
                              RTMPProtocolStringsLower[protocol], hostname.av_len,
                              hostname.av_val, port, app.av_len, app.av_val);
		tcUrl.av_val = (char *) malloc(tcUrl.av_len + 1);
		strcpy(tcUrl.av_val, str);
   }
	
	
	
	// User defined seek offset
	if (dStartOffset > 0)
   {
		// Live stream
		if (bLiveStream)
		{
			RTMP_Log(RTMP_LOGWARNING,
                  "Can't seek in a live stream, ignoring --start option");
			dStartOffset = 0;
		}
   }
	
	int dSeek = 0;
   RTMP_SetupStream(&rtmp, protocol, &hostname, port, &sockshost, &playpath,
                    &tcUrl, &swfUrl, &pageUrl, &app, &auth, &swfHash, swfSize,
                    &flashVer, &subscribepath, 0, dSeek, dStopOffset, bLiveStream, timeout);
   
   RTMP_EnableWrite(&rtmp);
	RTMP_Connect(&rtmp, NULL);

   int strId = RTMP_SendCreateStream(&rtmp);
   int err = RTMP_ConnectStream(&rtmp, 0);
   
	if (!bLiveStream && !(protocol & RTMP_FEATURE_HTTP))
		rtmp.Link.lFlags |= RTMP_LF_BUFX;
}


- (void)writeBytes:(char*)buffer N:(int)num {
   if (RTMP_IsConnected(&rtmp)) {
      int status = WriteN(&rtmp, buffer, num);
   }
}

@end
