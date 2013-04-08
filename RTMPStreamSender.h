
#import <Foundation/Foundation.h>

#include <rtmp_sys.h>
#include <log.h>
#include <rtmp.h>



/*
 Class, that should be used to send bytes to rtmp stream
 */

@interface RTMPStreamSender : NSObject {
	NSString *url;
	
@private
	
	int nStatus;
	int nSkipKeyFrames;	// skip this number of keyframes when resuming
	
	int bOverrideBufferTime;	// if the user specifies a buffer time override this is true
	uint32_t bufferTime;
	
	// meta header and initial frame for the resume mode (they are read from the file and compared with
	// the stream we are trying to continue
	char *metaHeader;
	uint32_t nMetaHeaderSize;
	
	int initialFrameType;	// tye: audio or video
	
	AVal hostname;
	AVal playpath;
	AVal subscribepath;
	int port;
	int protocol;
	int retries;
	int bLiveStream;	// is it a live stream? then we can't seek/resume
	int bHashes;		// display byte counters not hashes by default
	
	long int timeout;	// timeout connection after 120 seconds
	uint32_t dStartOffset;	// seek position in non-live mode
	uint32_t dStopOffset;
	RTMP rtmp;
	
	AVal swfUrl;
	AVal tcUrl;
	AVal pageUrl;
	AVal app;
	AVal auth;
	AVal swfHash;
	uint32_t swfSize;
	AVal flashVer;
	AVal sockshost;
	
	BOOL started;
}


/*
 url =  rtmp://[url to server]/[app name]/[channel name],
 for example,  @"rtmp://www.server.com/live/livestream"
 */


- (id)initWithURL:(NSString *)url;
- (void)connect;
- (void)writeBytes:(char*)buffer N:(int)num;


@end
