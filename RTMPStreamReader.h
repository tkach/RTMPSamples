
#import <Foundation/Foundation.h>

#define RD_SUCCESS		0
#define RD_FAILED		1
#define RD_INCOMPLETE		2

#define DEF_TIMEOUT	30	/* seconds */
#define DEF_BUFTIME	(10 * 60 * 60 * 1000)	/* 10 hours default */
#define DEF_SKIPFRM	0

#define	SET_BINMODE(f)

#define STR2AVAL(av,str)	av.av_val = str; av.av_len = strlen(av.av_val)


#include <rtmp_sys.h>
#include <log.h>
#include <rtmp.h>


@class RTMPStreamReader;


@protocol RTMPStreamReaderDelegate <NSObject>

@optional
- (void)streamReader:(RTMPStreamReader *)reader didConnectToURL:(NSString *)url;
- (void)streamReader:(RTMPStreamReader *)reader didReadBytes:(char *)bytes length:(int)length;

@end


@interface RTMPStreamReader : NSObject {
   NSString *_url;
	
@private
	
	int nStatus;
	double percent;
	double duration;
	
	int nSkipKeyFrames;	// skip this number of keyframes when resuming
	
	int bOverrideBufferTime;	// if the user specifies a buffer time override this is true
	int bStdoutMode;	// if true print the stream directly to stdout, messages go to stderr
	int bResume;		// true in resume mode
	uint32_t dSeek;		// seek position in resume mode, 0 otherwise
	uint32_t bufferTime;
	
	// meta header and initial frame for the resume mode (they are read from the file and compared with
	// the stream we are trying to continue
	char *metaHeader;
	uint32_t nMetaHeaderSize;
	
	// video keyframe for matching
	char *initialFrame;
	uint32_t nInitialFrameSize;
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
	
   int bufferSize;
   
	BOOL started;
}

@property (nonatomic, retain) NSString *url;
@property (nonatomic) id<RTMPStreamReaderDelegate> delegate;

- (id)initWithURL:(NSString *)url;
- (int)connect;
- (void)startReading;
- (void)readStep;

@end
