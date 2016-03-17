//
//  VideoConverter.h
//  diagral
//
//  Created by Dirk Faust on 15.03.16.
//  Copyright © 2016 viasys GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "avformat.h"
#include "avfilter.h"
#include "swscale.h"
#include "swresample.h"
#include "pixdesc.h"


#include "avcodec.h"
#include "avfiltergraph.h"
#include "buffersink.h"
#include "buffersrc.h"
#include "opt.h"

@interface VideoConverter : NSObject

typedef struct FilteringContext {
    AVFilterContext* buffersink_ctx;
    AVFilterContext* buffersrc_ctx;
    AVFilterGraph* filter_graph;
} FilteringContext;

@property (readwrite,nonatomic) AVFormatContext* ifmt_ctx;
@property (readwrite,nonatomic) AVFormatContext* ofmt_ctx;
@property (readwrite,nonatomic) FilteringContext* filter_ctx;

-(int) openInputFile: (const char*) strInputFile;
-(int) openOutputFile: (const char*) strOutputFile;
-(int) init_filter:(FilteringContext*)fctx :(AVCodecContext*) dec_ctx :(AVCodecContext*) enc_ctx
                  :(const char*) filter_spec;
-(int) init_filters;
-(int) encode_write_frame: (AVFrame*)filt_frame:(unsigned int)stream_index:(int*)got_frame;
-(int) filter_encode_write_frame: (AVFrame*)frame:(unsigned int)stream_index;
-(int) flush_encoder: (unsigned int)stream_index;



-(int) convertToIOSMP4: (NSString*) strInputfile :(NSString*) strOutputFile;

@end
