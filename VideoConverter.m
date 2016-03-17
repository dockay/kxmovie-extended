//
//  VideoConverter.m
//  diagral
//
//  Created by Dirk Faust on 15.03.16.
//  Copyright © 2016 viasys GmbH. All rights reserved.
//
// C => ObjectiveC ==> https://github.com/FFmpeg/FFmpeg/blob/master/doc/examples/transcoding.c
// + GlobalHeaders and fixes
// + Audio stream strip temporary until iOS solution found for AAC audio in MP4 containers
//   --> Search for 16.03.2016 to re-enable

#import "VideoConverter.h"

@implementation VideoConverter

-(int) openInputFile: (const char*) strInputFile
{
    int ret;
    unsigned int i;
    
    _ifmt_ctx = NULL;
    if ((ret = avformat_open_input(&_ifmt_ctx, strInputFile, NULL, NULL)) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot open input file\n");
        return ret;
    }
    
    if ((ret = avformat_find_stream_info(_ifmt_ctx, NULL)) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot find stream information\n");
        return ret;
    }
    
    for (i = 0; i < _ifmt_ctx->nb_streams; i++) {
        AVStream *stream;
        AVCodecContext *codec_ctx;
        stream = _ifmt_ctx->streams[i];
        codec_ctx = stream->codec;
        /* Reencode video & audio and remux subtitles etc. */
        if (codec_ctx->codec_type == AVMEDIA_TYPE_VIDEO
            || codec_ctx->codec_type == AVMEDIA_TYPE_AUDIO) {
            /* Open decoder */
            ret = avcodec_open2(codec_ctx,
                                avcodec_find_decoder(codec_ctx->codec_id), NULL);
            if (ret < 0) {
                av_log(NULL, AV_LOG_ERROR, "Failed to open decoder for stream #%u\n", i);
                return ret;
            }
        }
    }
    
    av_dump_format(_ifmt_ctx, 0, strInputFile, 0);
    return 0;
}

-(int) openOutputFile: (const char*) strOutputFile
{
    AVStream *out_stream;
    AVStream *in_stream;
    AVCodecContext *dec_ctx, *enc_ctx;
    AVCodec *encoder;
    int ret;
    unsigned int i;
    
    _ofmt_ctx = NULL;
    avformat_alloc_output_context2(&_ofmt_ctx, NULL, NULL, strOutputFile);
    if (!_ofmt_ctx) {
        av_log(NULL, AV_LOG_ERROR, "Could not create output context\n");
        return AVERROR_UNKNOWN;
    }
    
    // TODO: 16.03.2016 REMOVE "if (_ifmt_ctx->streams[i]->codec->codec_type != AVMEDIA_TYPE_AUDIO)" when iOS AUDIO HAS BEEN FIXED
    for (i = 0; i < _ifmt_ctx->nb_streams; i++) if (_ifmt_ctx->streams[i]->codec->codec_type != AVMEDIA_TYPE_AUDIO) {
        out_stream = avformat_new_stream(_ofmt_ctx, NULL);
        if (!out_stream) {
            av_log(NULL, AV_LOG_ERROR, "Failed allocating output stream\n");
            return AVERROR_UNKNOWN;
        }
        
        in_stream = _ifmt_ctx->streams[i];
        dec_ctx = in_stream->codec;
        enc_ctx = out_stream->codec;
        
        if (dec_ctx->codec_type == AVMEDIA_TYPE_VIDEO
            || dec_ctx->codec_type == AVMEDIA_TYPE_AUDIO) {
            /* in this example, we choose transcoding to same codec */
            
            // TODO: Audio Transcode? IOS is compatible with PCM??
            
            NSLog(@"CODEC ID is %d", dec_ctx->codec_id);
            
            encoder = avcodec_find_encoder(dec_ctx->codec_id);
            if (!encoder) {
                av_log(NULL, AV_LOG_FATAL, "Necessary encoder not found\n");
                return AVERROR_INVALIDDATA;
            }
        
            AVDictionary* pDict = NULL;
            if (dec_ctx->codec_type == AVMEDIA_TYPE_VIDEO) {
                
                av_dict_set(&pDict, "vprofile", "baseline", 0); // add an entry
                av_dict_set(&pDict, "preset", "slow", 0);
                av_dict_set(&pDict, "maxrate", "500k", 0);
                
                enc_ctx->height = dec_ctx->height;
                enc_ctx->width = dec_ctx->width;
                enc_ctx->sample_aspect_ratio = dec_ctx->sample_aspect_ratio;
                // take first format from list of supported formats
                enc_ctx->pix_fmt = encoder->pix_fmts[0];
                // video time_base can be set to whatever is handy and supported by encoder
                enc_ctx->time_base = dec_ctx->time_base;
                
                // Set up to iOS compatibles stuff
                enc_ctx->qmin = 10;
                enc_ctx->qmax = 51;
                enc_ctx->max_qdiff = 4;
                enc_ctx->me_range = 16;
                enc_ctx->level = 31;
                enc_ctx->bit_rate_tolerance = 0;
                enc_ctx->sample_aspect_ratio.num = 1;
                enc_ctx->sample_aspect_ratio.den = 1;
                enc_ctx->bit_rate = 500 * 1024;
                enc_ctx->profile = FF_PROFILE_H264_BASELINE;
                enc_ctx->rc_max_rate = 0;
                enc_ctx->rc_buffer_size = 0;
                enc_ctx->gop_size = 15 * 2;
                enc_ctx->max_b_frames = 0;
                enc_ctx->b_frame_strategy = 1;
                enc_ctx->coder_type = 1;
                enc_ctx->me_cmp = 1;
                enc_ctx->me_range = 16;
                enc_ctx->qmin = 10;
                enc_ctx->qmax = 51;
                enc_ctx->scenechange_threshold = enc_ctx->gop_size;
                enc_ctx->flags |= CODEC_FLAG_LOOP_FILTER | CODEC_FLAG_GLOBAL_HEADER;
                enc_ctx->me_subpel_quality = 5;
                enc_ctx->i_quant_factor = 0.71;
                enc_ctx->qcompress = 0.6;
                enc_ctx->max_qdiff = 4;
                
                
            } else {
                /*
                // AUDIO
                encoder = avcodec_find_encoder(AV_CODEC_ID_AAC);
                if (!encoder) NSLog(@"Audio encoder not found!");
  //              enc_ctx = avcodec_alloc_context3(encoder);
                enc_ctx->sample_rate = dec_ctx->sample_rate;
                enc_ctx->channel_layout = dec_ctx->channel_layout;
                enc_ctx->channels = av_get_channel_layout_nb_channels(dec_ctx->channel_layout);
                // take first format from list of supported formats
                enc_ctx->sample_fmt = encoder->sample_fmts[0];
                enc_ctx->time_base = (AVRational){1, enc_ctx->sample_rate};
                enc_ctx->flags |= CODEC_FLAG_GLOBAL_HEADER;
                 */
            }

            /* Third parameter can be used to pass settings to encoder */
            ret = avcodec_open2(enc_ctx, encoder, &pDict);
            if (ret < 0) {
                av_log(NULL, AV_LOG_ERROR, "Cannot open encoder for stream #%u\n", i);
                return ret;
            }
 
            /*
            // TODO: Das hier ist der allerletzte KACK - das muss im ENC erzeugt werden.
            // Es fehlt SPS, PPS - der scheiss x264 macht das nur nicht!
            if (dec_ctx->extradata_size > 0 && 1 == 0) {
                enc_ctx->extradata_size = dec_ctx->extradata_size;
                enc_ctx->extradata = malloc(dec_ctx->extradata_size + AV_INPUT_BUFFER_PADDING_SIZE);
                memcpy(enc_ctx->extradata,dec_ctx->extradata, dec_ctx->extradata_size);
            }
             */
            
            NSLog(@"EXTRA DATA SIZE ENC %d", enc_ctx->extradata_size);
        } else if (dec_ctx->codec_type == AVMEDIA_TYPE_UNKNOWN) {
            av_log(NULL, AV_LOG_FATAL, "Elementary stream #%d is of unknown type, cannot proceed\n", i);
            return AVERROR_INVALIDDATA;
        } else {
            /* if this stream must be remuxed */
            ret = avcodec_copy_context(_ofmt_ctx->streams[i]->codec,
                                       _ifmt_ctx->streams[i]->codec);
            if (ret < 0) {
                av_log(NULL, AV_LOG_ERROR, "Copying stream context failed\n");
                return ret;
            }
        }
        
        if (_ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER)
            enc_ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
        
    }
    av_dump_format(_ofmt_ctx, 0, strOutputFile, 1);
    
    if (!(_ofmt_ctx->oformat->flags & AVFMT_NOFILE)) {
        ret = avio_open(&_ofmt_ctx->pb, strOutputFile, AVIO_FLAG_WRITE);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Could not open output file '%s'", strOutputFile);
            return ret;
        }
    }
    
    /* init muxer, write output file header */
    ret = avformat_write_header(_ofmt_ctx, NULL);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "Error occurred when opening output file\n");
        return ret;
    }
    
    return 0;
}

-(int) init_filter:(FilteringContext*)fctx :(AVCodecContext*) dec_ctx :(AVCodecContext*) enc_ctx
                  :(const char*) filter_spec
{
    char args[512];
    int ret = 0;
    AVFilter *buffersrc = NULL;
    AVFilter *buffersink = NULL;
    AVFilterContext *buffersrc_ctx = NULL;
    AVFilterContext *buffersink_ctx = NULL;
    AVFilterInOut *outputs = avfilter_inout_alloc();
    AVFilterInOut *inputs  = avfilter_inout_alloc();
    AVFilterGraph *filter_graph = avfilter_graph_alloc();
    
    if (!outputs || !inputs || !filter_graph) {
        ret = AVERROR(ENOMEM);
        goto end;
    }
    
    if (dec_ctx->codec_type == AVMEDIA_TYPE_VIDEO) {
        buffersrc = avfilter_get_by_name("buffer");
        buffersink = avfilter_get_by_name("buffersink");
        if (!buffersrc || !buffersink) {
            av_log(NULL, AV_LOG_ERROR, "filtering source or sink element not found\n");
            ret = AVERROR_UNKNOWN;
            goto end;
        }
        
        snprintf(args, sizeof(args),
                 "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d",
                 dec_ctx->width, dec_ctx->height, dec_ctx->pix_fmt,
                 dec_ctx->time_base.num, dec_ctx->time_base.den,
                 dec_ctx->sample_aspect_ratio.num,
                 dec_ctx->sample_aspect_ratio.den);
        
        ret = avfilter_graph_create_filter(&buffersrc_ctx, buffersrc, "in",
                                           args, NULL, filter_graph);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Cannot create buffer source\n");
            goto end;
        }
        
        ret = avfilter_graph_create_filter(&buffersink_ctx, buffersink, "out",
                                           NULL, NULL, filter_graph);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Cannot create buffer sink\n");
            goto end;
        }
        
        ret = av_opt_set_bin(buffersink_ctx, "pix_fmts",
                             (uint8_t*)&enc_ctx->pix_fmt, sizeof(enc_ctx->pix_fmt),
                             AV_OPT_SEARCH_CHILDREN);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Cannot set output pixel format\n");
            goto end;
        }
    } else if (dec_ctx->codec_type == AVMEDIA_TYPE_AUDIO) {
        buffersrc = avfilter_get_by_name("abuffer");
        buffersink = avfilter_get_by_name("abuffersink");
        if (!buffersrc || !buffersink) {
            av_log(NULL, AV_LOG_ERROR, "filtering source or sink element not found\n");
            ret = AVERROR_UNKNOWN;
            goto end;
        }
        
        if (!dec_ctx->channel_layout)
            dec_ctx->channel_layout =
            av_get_default_channel_layout(dec_ctx->channels);
        snprintf(args, sizeof(args),
                 "time_base=%d/%d:sample_rate=%d:sample_fmt=%s:channel_layout=0x%"PRIx64,
                 dec_ctx->time_base.num, dec_ctx->time_base.den, dec_ctx->sample_rate,
                 av_get_sample_fmt_name(dec_ctx->sample_fmt),
                 dec_ctx->channel_layout);
        ret = avfilter_graph_create_filter(&buffersrc_ctx, buffersrc, "in",
                                           args, NULL, filter_graph);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Cannot create audio buffer source\n");
            goto end;
        }
        
        ret = avfilter_graph_create_filter(&buffersink_ctx, buffersink, "out",
                                           NULL, NULL, filter_graph);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Cannot create audio buffer sink\n");
            goto end;
        }
        
        ret = av_opt_set_bin(buffersink_ctx, "sample_fmts",
                             (uint8_t*)&enc_ctx->sample_fmt, sizeof(enc_ctx->sample_fmt),
                             AV_OPT_SEARCH_CHILDREN);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Cannot set output sample format\n");
            goto end;
        }
        
        ret = av_opt_set_bin(buffersink_ctx, "channel_layouts",
                             (uint8_t*)&enc_ctx->channel_layout,
                             sizeof(enc_ctx->channel_layout), AV_OPT_SEARCH_CHILDREN);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Cannot set output channel layout\n");
            goto end;
        }
        
        ret = av_opt_set_bin(buffersink_ctx, "sample_rates",
                             (uint8_t*)&enc_ctx->sample_rate, sizeof(enc_ctx->sample_rate),
                             AV_OPT_SEARCH_CHILDREN);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Cannot set output sample rate\n");
            goto end;
        }
    } else {
        ret = AVERROR_UNKNOWN;
        goto end;
    }
    
    /* Endpoints for the filter graph. */
    outputs->name       = av_strdup("in");
    outputs->filter_ctx = buffersrc_ctx;
    outputs->pad_idx    = 0;
    outputs->next       = NULL;
    
    inputs->name       = av_strdup("out");
    inputs->filter_ctx = buffersink_ctx;
    inputs->pad_idx    = 0;
    inputs->next       = NULL;
    
    if (!outputs->name || !inputs->name) {
        ret = AVERROR(ENOMEM);
        goto end;
    }
    
    if ((ret = avfilter_graph_parse_ptr(filter_graph, filter_spec,
                                        &inputs, &outputs, NULL)) < 0)
        goto end;
    
    if ((ret = avfilter_graph_config(filter_graph, NULL)) < 0)
        goto end;
    
    /* Fill FilteringContext */
    fctx->buffersrc_ctx = buffersrc_ctx;
    fctx->buffersink_ctx = buffersink_ctx;
    fctx->filter_graph = filter_graph;
    
end:
    avfilter_inout_free(&inputs);
    avfilter_inout_free(&outputs);
    
    return ret;
}

-(int) init_filters
{
    const char *filter_spec;
    unsigned int i;
    int ret;
    _filter_ctx = av_malloc_array(_ifmt_ctx->nb_streams, sizeof(*_filter_ctx));
    if (!_filter_ctx)
        return AVERROR(ENOMEM);
    
    for (i = 0; i < _ifmt_ctx->nb_streams; i++) {
        _filter_ctx[i].buffersrc_ctx  = NULL;
        _filter_ctx[i].buffersink_ctx = NULL;
        _filter_ctx[i].filter_graph   = NULL;
        if (!(_ifmt_ctx->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO
              || _ifmt_ctx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO))
            continue;
        
        
        if (_ifmt_ctx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO)
            filter_spec = "null"; /* passthrough (dummy) filter for video */
        else
            filter_spec = "anull"; /* passthrough (dummy) filter for audio */
        
        if (_ofmt_ctx->streams[i]) {
            ret = [self init_filter:&_filter_ctx[i]:_ifmt_ctx->streams[i]->codec:
               _ofmt_ctx->streams[i]->codec:filter_spec];
        } else
            if (ret) {
                ret = 0;
            }
            return ret;
    }
    return 0;
}

-(int) encode_write_frame:(AVFrame*)filt_frame:(unsigned int)stream_index:(int*)got_frame
{
    int ret;
    int got_frame_local;
    AVPacket enc_pkt;
    int (*enc_func)(AVCodecContext *, AVPacket *, const AVFrame *, int *) =
    (_ifmt_ctx->streams[stream_index]->codec->codec_type ==
     AVMEDIA_TYPE_VIDEO) ? avcodec_encode_video2 : avcodec_encode_audio2;
    
    if (!got_frame)
        got_frame = &got_frame_local;
    
    // av_log(NULL, AV_LOG_INFO, "Encoding frame\n");
    /* encode filtered frame */
    enc_pkt.data = NULL;
    enc_pkt.size = 0;
    av_init_packet(&enc_pkt);
    ret = enc_func(_ofmt_ctx->streams[stream_index]->codec, &enc_pkt,
                   filt_frame, got_frame);
    av_frame_free(&filt_frame);
    if (ret < 0)
        return ret;
    if (!(*got_frame))
        return 0;
    
    /* prepare packet for muxing */
    enc_pkt.stream_index = stream_index;
    av_packet_rescale_ts(&enc_pkt,
                         _ofmt_ctx->streams[stream_index]->codec->time_base,
                         _ofmt_ctx->streams[stream_index]->time_base);
    
//    av_log(NULL, AV_LOG_DEBUG, "Muxing frame\n");
    /* mux encoded frame */
    ret = av_interleaved_write_frame(_ofmt_ctx, &enc_pkt);
    return ret;
}

-(int) filter_encode_write_frame: (AVFrame*)frame:(unsigned int)stream_index{
    int ret;
    AVFrame *filt_frame;
    
//    av_log(NULL, AV_LOG_INFO, "Pushing decoded frame to filters\n");
    /* push the decoded frame into the filtergraph */
    ret = av_buffersrc_add_frame_flags(_filter_ctx[stream_index].buffersrc_ctx,
                                       frame, 0);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "Error while feeding the filtergraph\n");
        return ret;
    }
    
    /* pull filtered frames from the filtergraph */
    while (1) {
        filt_frame = av_frame_alloc();
        if (!filt_frame) {
            ret = AVERROR(ENOMEM);
            break;
        }
  //      av_log(NULL, AV_LOG_INFO, "Pulling filtered frame from filters\n");
        ret = av_buffersink_get_frame(_filter_ctx[stream_index].buffersink_ctx,
                                      filt_frame);
        if (ret < 0) {
            /* if no more frames for output - returns AVERROR(EAGAIN)
             * if flushed and no more frames for output - returns AVERROR_EOF
             * rewrite retcode to 0 to show it as normal procedure completion
             */
            if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF)
                ret = 0;
            av_frame_free(&filt_frame);
            break;
        }
        
        filt_frame->pict_type = AV_PICTURE_TYPE_NONE;
        ret = [self encode_write_frame:filt_frame:stream_index:NULL];
        if (ret < 0)
            break;
    }
    
    return ret;
}

-(int) flush_encoder: (unsigned int)stream_index
{
    int ret;
    int got_frame;
    
    if (!(_ofmt_ctx->streams[stream_index]->codec->codec->capabilities &
          AV_CODEC_CAP_DELAY))
        return 0;
    
    while (1) {
      //  av_log(NULL, AV_LOG_INFO, "Flushing stream #%u encoder\n", stream_index);
        ret = [self encode_write_frame:NULL:stream_index:&got_frame];
        if (ret < 0)
            break;
        if (!got_frame)
            return 0;
    }
    return ret;
}


-(int) convertToIOSMP4: (NSString*) strInputfile :(NSString*) strOutputFile
{
    int ret;
    AVPacket packet = { .data = NULL, .size = 0 };
    AVFrame *frame = NULL;
    enum AVMediaType type;
    unsigned int stream_index;
    unsigned int i;
    int got_frame;
    int (*dec_func)(AVCodecContext *, AVFrame *, int *, const AVPacket *);
    
    av_register_all();
    avfilter_register_all();
    
    if ((ret = [self openInputFile:[strInputfile cStringUsingEncoding:NSUTF8StringEncoding]]) < 0)
        goto end;
    if ((ret = [self openOutputFile:[strOutputFile cStringUsingEncoding:NSUTF8StringEncoding]]) < 0)
        goto end;
    if ((ret = [self init_filters]) < 0)
        goto end;
    
    /* read all packets */
    while (1) {
        if ((ret = av_read_frame(_ifmt_ctx, &packet)) < 0)
            break;
        stream_index = packet.stream_index;
        type = _ifmt_ctx->streams[packet.stream_index]->codec->codec_type;
      //  av_log(NULL, AV_LOG_DEBUG, "Demuxer gave frame of stream_index %u\n", stream_index);
        
        if (_filter_ctx[stream_index].filter_graph) {
          //  av_log(NULL, AV_LOG_DEBUG, "Going to reencode&filter the frame\n");
            frame = av_frame_alloc();
            if (!frame) {
                ret = AVERROR(ENOMEM);
                break;
            }
            av_packet_rescale_ts(&packet,
                                 _ifmt_ctx->streams[stream_index]->time_base,
                                 _ifmt_ctx->streams[stream_index]->codec->time_base);
            dec_func = (type == AVMEDIA_TYPE_VIDEO) ? avcodec_decode_video2 :
            avcodec_decode_audio4;
            ret = dec_func(_ifmt_ctx->streams[stream_index]->codec, frame,
                           &got_frame, &packet);
            if (ret < 0) {
                av_frame_free(&frame);
                av_log(NULL, AV_LOG_ERROR, "Decoding failed\n");
                break;
            }
            
            if (got_frame) {
                frame->pts = av_frame_get_best_effort_timestamp(frame);
                
                // TODO: 16.03.2016 - RE ENBABLE AUDIO AGAIN WHEN IOS AUDIO FXIED
                if (type != AVMEDIA_TYPE_AUDIO) {
                    ret = [self filter_encode_write_frame:frame:stream_index];
                } else {
                    ret = 0;
                }
                av_frame_free(&frame);
                if (ret < 0)
                    goto end;
            } else {
                av_frame_free(&frame);
            }
        } else {
            /* remux this frame without reencoding */
            /* TODO: 16.03.2016 - NO DONT DO THIS FOR AUDIO
            av_packet_rescale_ts(&packet,
                                 _ifmt_ctx->streams[stream_index]->time_base,
                                 _ofmt_ctx->streams[stream_index]->time_base);
            
            ret = av_interleaved_write_frame(_ofmt_ctx, &packet);
            if (ret < 0)
                goto end;
             */
        }
        av_packet_unref(&packet);
    }
    
    /* flush filters and encoders */
    for (i = 0; i < _ifmt_ctx->nb_streams; i++) {
        /* flush filter */
        if (!_filter_ctx[i].filter_graph)
            continue;
        ret = [self filter_encode_write_frame:NULL:i];
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Flushing filter failed\n");
            goto end;
        }
        
        /* flush encoder */
        ret = [self flush_encoder:i];
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Flushing encoder failed\n");
            goto end;
        }
    }
    
    av_write_trailer(_ofmt_ctx);
end:
    av_packet_unref(&packet);
    av_frame_free(&frame);
    if (_ifmt_ctx) for (i = 0; i < _ifmt_ctx->nb_streams; i++) {
        avcodec_close(_ifmt_ctx->streams[i]->codec);
        if (_ofmt_ctx && _ofmt_ctx->nb_streams > i && _ofmt_ctx->streams[i] && _ofmt_ctx->streams[i]->codec)
            avcodec_close(_ofmt_ctx->streams[i]->codec);
        if (_filter_ctx && _filter_ctx[i].filter_graph)
            avfilter_graph_free(&_filter_ctx[i].filter_graph);
    }
    if (_filter_ctx) av_free(_filter_ctx);
    if (_ifmt_ctx) avformat_close_input(&_ifmt_ctx);
    if (_ofmt_ctx && !(_ofmt_ctx->oformat->flags & AVFMT_NOFILE))
        avio_closep(&_ofmt_ctx->pb);
    avformat_free_context(_ofmt_ctx);
    
    if (ret < 0)
        av_log(NULL, AV_LOG_ERROR, "Error occurred: %s\n", av_err2str(ret));
    
    return ret ? 1 : 0;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        // superclass successfully initialized, further
        // initialization happens here ...
    }
    return self;
}

@end
