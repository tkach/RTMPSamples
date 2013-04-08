
#import "RTMPStreamReader.h"


@interface RTMPStreamReader()

- (void)clean;

@end

@implementation RTMPStreamReader

@synthesize url = _url;
@synthesize delegate;

- (id)initWithURL:(NSString *)url {
	self = [super init];
	if (self) {
      self.url = url;
		[self clean];  
		return self;
	}
	return nil;
}


static char *buffer = nil;


- (void) clean {
	if (RTMP_IsConnected(&rtmp)) {
		RTMP_DeleteStream(&rtmp);
		RTMP_Close(&rtmp);
	}
	nStatus = RD_SUCCESS;
	percent = 0;
	duration = 0.0;
	
	nSkipKeyFrames = DEF_SKIPFRM;	// skip this number of keyframes when resuming
	
	bOverrideBufferTime = FALSE;	// if the user specifies a buffer time override this is true
	bStdoutMode = FALSE;	// if true print the stream directly to stdout, messages go to stderr
	bResume = FALSE;		// true in resume mode
	dSeek = 0;		// seek position in resume mode, 0 otherwise
	bufferTime = DEF_BUFTIME;
	
	// meta header and initial frame for the resume mode (they are read from the file and compared with
	// the stream we are trying to continue
	metaHeader = 0;
	nMetaHeaderSize = 0;
	
	// video keyframe for matching
	initialFrame = 0;
	nInitialFrameSize = 0;
	initialFrameType = 0;	// tye: audio or video
	
	hostname = (AVal){ 0, 0 };
	playpath = (AVal){ 0, 0 };
	subscribepath = (AVal){ 0, 0 };
	port = -1;
	protocol = RTMP_PROTOCOL_UNDEFINED;
	retries = 0;
	bLiveStream = true;	// is it a live stream? then we can't seek/resume
	bHashes = FALSE;		// display byte counters not hashes by default
	
	timeout = DEF_TIMEOUT;	// timeout connection after 120 seconds
	dStartOffset = 0;	// seek position in non-live mode
	dStopOffset = 0;
   //	rtmp = (RTMP){ 0 };
	
	swfUrl = (AVal){ 0, 0 };
	tcUrl = (AVal){ 0, 0 };
	pageUrl = (AVal){ 0, 0 };
	app = (AVal){ 0, 0 };
	auth = (AVal){ 0, 0 };
	swfHash = (AVal){ 0, 0 };
	swfSize = 0;
	flashVer = (AVal){ 0, 0 };
	sockshost = (AVal){ 0, 0 };
   
   bufferSize = 64 * 1024;
   buffer = (char *) malloc(bufferSize);
}


- (int)connect {
   started = NO;
   
	char *opt = (char*)[self.url UTF8String];
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
   
//   RTMP_SetupStream(&rtmp, protocol, &hostname, port, &sockshost, &playpath,
//                    &tcUrl, &swfUrl, &pageUrl, &app, &auth, &swfHash, swfSize,
//                    &flashVer, &subscribepath, dSeek, dStopOffset, bLiveStream, timeout);

	
	if (!bLiveStream && !(protocol & RTMP_FEATURE_HTTP))
		rtmp.Link.lFlags |= RTMP_LF_BUFX;
   
   if (RTMP_Connect(&rtmp, NULL)) {
      if (RTMP_ConnectStream(&rtmp, dSeek))
      {
         nStatus = RD_SUCCESS;
         if ([self.delegate respondsToSelector:@selector(streamReader:didConnectToURL:)]) {
            [self.delegate streamReader:self didConnectToURL:self.url];
         }
      }
   }
   else {
      nStatus = RD_FAILED;
   }
   
   return nStatus;
}

- (void)startReading {
   int32_t now, lastUpdate;
   
   
   int nRead = 0;

   unsigned long lastPercent = 0;
   
   rtmp.m_read.timestamp = 0;
   
   rtmp.m_read.initialFrameType = initialFrameType;
   rtmp.m_read.nResumeTS = dSeek;
   rtmp.m_read.metaHeader = metaHeader;
   rtmp.m_read.initialFrame = initialFrame;
   rtmp.m_read.nMetaHeaderSize = nMetaHeaderSize;
   rtmp.m_read.nInitialFrameSize = nInitialFrameSize;
   
   now = RTMP_GetTime();
   lastUpdate = now - 1000;
   
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, NULL), ^{
      [self readStep];
   });
}


- (void)readStep {
   NSLog(@"read stepXXX:");
   if (RTMP_IsConnected(&rtmp)) {
      int nRead = 0;
      nRead = RTMP_Read(&rtmp, buffer, bufferSize);
      
      if (nRead > 0)
      {         
         //RTMP_LogPrintf("write %dbytes (%.1f kB)\n", nRead, nRead/1024.0);
         if (duration <= 0)	// if duration unknown try to get it from the stream (onMetaData)
            duration = RTMP_GetDuration(&rtmp);
         
         if (duration > 0)
         {
            // make sure we claim to have enough buffer time!
            if (!bOverrideBufferTime && bufferTime < (duration * 1000.0))
            {
               bufferTime = (uint32_t) (duration * 1000.0) + 5000;	// extra 5sec to make sure we've got enough
               
               RTMP_Log(RTMP_LOGDEBUG,
                        "Detected that buffer time is less than duration, resetting to: %dms",
                        bufferTime);
               RTMP_SetBufferMS(&rtmp, bufferTime);
               RTMP_UpdateBufferMS(&rtmp);
            }
         }
         
         if ([self.delegate respondsToSelector:@selector(streamReader:didReadBytes:length:)]) {
            [self.delegate streamReader:self didReadBytes:buffer length:nRead];
         }
      }
      
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
         [self readStep];
      });      
   }
}


- (void) dealloc {
   free(buffer);
	RTMP_DeleteStream(&rtmp);
	RTMP_Close(&rtmp);
//	[super dealloc];
}


@end
