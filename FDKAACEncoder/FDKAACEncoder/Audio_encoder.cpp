//
//  Audio_encoder.cpp
//  FDKAACEncoder
//
//  Created by luowailin on 2019/10/21.
//  Copyright © 2019 luowailin. All rights reserved.
//

#include "Audio_encoder.hpp"

#define LOG_TAG "AudioEncoder"

AudioEncoder::AudioEncoder(){
    
}

AudioEncoder::~AudioEncoder(){
    
}

//分配Codec相关内容，并给AVFormatContext上下文填充一轨AVStream
int AudioEncoder::alloc_audio_stream(const char *codec_name){
    AVCodec *codec;
    AVSampleFormat preferedSampleFMT = AV_SAMPLE_FMT_S16;
    int preferedChannels = audioChannels;
    int preferedSampleRate = audioSampleRate;
    
    //给avFromatContext上下文填充一轨AVStream
    audioStream = avformat_new_stream(avFormatContext, nullptr); /**avformat_new_stream就是创建new stream添加到Media file*/
    audioStream->id = 1;
    
    //找到编码器
    //codec = avcodec_find_encoder_by_name(codec_name);
    codec = avcodec_find_encoder(AV_CODEC_ID_AAC);
    if (!codec) {
        LOGI("Couldn't find a valid audio codec");
        return -1;
    }
    
    //分配Codec相关内容
     /**avCodecContext = avcodec_alloc_context3(codec); //用这个创建出错
    avcodec_parameters_to_context(avCodecContext, audioStream->codecpar);*/
    avCodecContext = audioStream->codec;

    avCodecContext->codec_type = AVMEDIA_TYPE_AUDIO;
    avCodecContext->sample_rate = audioSampleRate;
    if (publishBitRate > 0) {
        avCodecContext->bit_rate = publishBitRate;
    } else {
        avCodecContext->bit_rate = PUBLISH_BITE_RATE;
    }
    
    avCodecContext->sample_fmt = preferedSampleFMT;
    avCodecContext->channel_layout = preferedChannels == 1 ? AV_CH_LAYOUT_MONO : AV_CH_LAYOUT_STEREO;
    avCodecContext->channels = av_get_channel_layout_nb_channels(avCodecContext->channel_layout);
    avCodecContext->profile = FF_PROFILE_AAC_LOW;
    LOGI("audioChannels is %d", audioChannels);
    LOGI("avcodecContext->channels is %d", avCodecContext->channels);
    avCodecContext->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    /**填充AVCodecContext的属性
     * 比较重要的一定要填充:
     * code_type AVMEDIA_TYPE_AUDIO代表是音频类型
     * bit_rate
     * sample_rate
     * channels
     * channel_layout  表达的意义跟channels是一样的，只不过可选值是两个常量 AV_CH_LAYOUT_MONO 单声道 AV_CH_LAYOUT_STEREO 立体声
     * sample_fmt  AV_SAMPLE_FMT_S16 即用一个short来表示一个采样点，
     * frame_size 为编码器指定frame_size的大小，一般指定1024作为一帧的大小
     */
    

    avCodecContext->codec_id = codec->id;
    
    
    if (codec->sample_fmts) { /** sample_fmts 支持的采样格式 (仅音频) */
        const enum AVSampleFormat *p = codec->sample_fmts;
        for (; *p != -1; p++) {
            /** if (*p == audioStream->codec->sample_fmt) {
                break;
            }*/
            if (*p == avCodecContext->sample_fmt) {
                break;
            }
        }
    
        if (*p == -1) {
            LOGI("sample format incompatible with codec. Defaulting to a format known to work....");
            avCodecContext->sample_fmt = codec->sample_fmts[0];
        }
    }
    
    if (codec->supported_samplerates) { /** supported_samplerates 支持的采样率 仅音频   channel_layouts 支持的声道数(仅音频)  supported_framerates 支持的帧率(仅视频) pix_fmts 支持的像素格式(仅视频) */
        const int *p = codec->supported_samplerates;
        int best = 0;
        int best_dist = INT_MAX;
        for (; *p; p++) {
            /** int dist = abs(audioStream->codec->sample_rate - *p); */
            int dist = abs(avCodecContext->sample_rate - *p);
            if (dist < best_dist) {
                best_dist = dist;
                best = *p;
            }
        }
        
        avCodecContext->sample_rate = best;
    }
    
    //是否需要重采样
    if (preferedChannels != avCodecContext->channels ||
        preferedSampleRate != avCodecContext->sample_rate ||
        preferedSampleFMT != avCodecContext->sample_fmt) {
        LOGI("channels is {%d, %d}", preferedChannels, avCodecContext->channels);
        LOGI("sample_rate is {%d, %d}", preferedSampleRate, avCodecContext->sample_rate);
        LOGI("sample_fmt is {%d, %d}", preferedSampleFMT, avCodecContext->sample_fmt);
        
        LOGI("AV_SAMPLE_FMT_S16P is %d AV_SAMPLE_FMT_S16 is %d AV_SAMPLE_FMT_FLTP is %d", AV_SAMPLE_FMT_S16P, AV_SAMPLE_FMT_S16, AV_SAMPLE_FMT_FLTP);
        
        swrContext = swr_alloc_set_opts(nullptr,
                                        av_get_default_channel_layout(avCodecContext->channels),
                                        (AVSampleFormat)avCodecContext->sample_fmt,
                                        avCodecContext->sample_rate,
                                        av_get_default_channel_layout(preferedChannels),
                                        preferedSampleFMT,
                                        preferedSampleRate,
                                        0,
                                        nullptr);
        
        if (!swrContext || swr_init(swrContext)) {
            if (swrContext) {
                swr_free(&swrContext);
            }
            return -1;
        }
    }
    
    //为该编码器上下文打开这个编码器，
    if (avcodec_open2(avCodecContext, codec, nullptr) < 0) {
        LOGI("Couldn't open codec");
        return -2;
    }
    
    avCodecContext->time_base.num = 1;
    avCodecContext->time_base.den = avCodecContext->sample_rate;
    avCodecContext->frame_size = 1024;

    return 0;
}


//初始化inputFrame
int AudioEncoder::alloc_avframe(){
    int ret = 0;
    AVSampleFormat preferedSampleFMT = AV_SAMPLE_FMT_S16;
    int preferedChannels = audioChannels;
    int preferedSampleRate = audioSampleRate;
    
    /**input_frame 作为客户端代码输入的PCM数据存放的地方，需要注意的是必须知道inputFrame分配的buffer的大小，*/
    input_frame = av_frame_alloc();
    if (!input_frame) {
        LOGI("Could not allocate audio frame\n");
        return -1;
    }
    
    input_frame->nb_samples = avCodecContext->frame_size;
    input_frame->format = preferedSampleFMT;
    input_frame->channel_layout = preferedChannels == 1 ? AV_CH_LAYOUT_MONO : AV_CH_LAYOUT_STEREO;
    input_frame->sample_rate = preferedSampleRate;
    //av_samples_get_buffer_size 这个方法主要是计算编码每一帧输入给编码器需要多少个字节。
    buffer_size = av_samples_get_buffer_size(nullptr,
                                             av_get_channel_layout_nb_channels(input_frame->channel_layout),
                                             input_frame->nb_samples,
                                             preferedSampleFMT,
                                             0); //计算buffer_Size = frame_size * sizeof(SInt16) * channels 其中frame_size 就是AVCodecContext中的frame_size
    
    //重采样的构造
    samples = (uint8_t *)av_malloc(buffer_size);
    samplesCursor = 0;
    if (!samples) {
        LOGI("Could not allocate %d bytes for samples buffer\n", buffer_size);
        return -2;
    }
    
    LOGI("allocate %d bytes for samples buffer\n", buffer_size);
    //samples 的缓冲数据赋值给input_frame
    ret = avcodec_fill_audio_frame(input_frame,
                                   av_get_channel_layout_nb_channels(input_frame->channel_layout),
                                   preferedSampleFMT,
                                   samples,
                                   buffer_size,
                                   0);
    if (ret < 0) {
        LOGI("Could not setup audio frame\n");
    }
    
    if (swrContext) {
        if (av_sample_fmt_is_planar(avCodecContext->sample_fmt)) {
            LOGI("Codec context sampleFormat is Planar..");
        }
        
        convert_data = (uint8_t **)calloc(avCodecContext->channels, sizeof(*convert_data));
        av_samples_alloc(convert_data,
                         nullptr,
                         avCodecContext->channels,
                         avCodecContext->frame_size,
                         avCodecContext->sample_fmt,
                         0);
        
        swrBufferSize = av_samples_get_buffer_size(nullptr,
                                                   avCodecContext->channels,
                                                   avCodecContext->frame_size,
                                                   avCodecContext->sample_fmt,
                                                   0);
        swrBuffer = (uint8_t *)av_mallocz(swrBufferSize); //av_malloc(swrBufferSize);
        
        LOGI("After av_malloc swrBuffer");
        
        swrFrame = av_frame_alloc(); //用于重采样，作为最终得到结果的AVFrame
        if (!swrFrame) {
            LOGI("Could not allocate swrFrame frame\n");
            return -1;
        }
        
        swrFrame->nb_samples = avCodecContext->frame_size;
        swrFrame->format = avCodecContext->sample_fmt;
        swrFrame->channel_layout = avCodecContext->channels == 1 ? AV_CH_LAYOUT_MONO : AV_CH_LAYOUT_STEREO;
        swrFrame->sample_rate = avCodecContext->sample_rate;
        ret = avcodec_fill_audio_frame(swrFrame,
                                       avCodecContext->channels,
                                       avCodecContext->sample_fmt,
                                       (const uint8_t *)swrBuffer,
                                       swrBufferSize,
                                       0);
        LOGI("After avcodec fill_audio_frame");
        if (ret < 0) {
            LOGI("avcodec fill audio frame error");
            return -1;
        }
    }
    return ret;
}

int AudioEncoder::init(int bitRate, int channels, int sampleRate, int bitsPerSample, const char *accFilePath, const char *codec_name){
    avCodecContext = nullptr;
    avFormatContext = nullptr;
    input_frame = nullptr;
    samples = nullptr;
    swrContext = nullptr;
    swrFrame = nullptr;
    swrBuffer = nullptr;
    this->isWriteHeaderSuccess = false;
    
    samplesCursor = 0;
    totalEncodeTimeMills = 0;
    totalSWRTimeMills = 0;
    
    this->publishBitRate = bitRate;
    this->audioChannels = channels;
    this->audioSampleRate = sampleRate;
    
    int ret;
    avformat_network_init();
    
    //step 1: 格式上下文
    avFormatContext = avformat_alloc_context(); //初始化
    LOGI("aacFilePath is %s", accFilePath);
    ret = avformat_alloc_output_context2(&avFormatContext,
                                         nullptr,
                                         nullptr,
                                         accFilePath);  //分配上下文即分配出封装格式
    if (ret != 0) {
        LOGI("avformatContext alloc failed:%s", av_err2str(ret));
        return -1;
    }
    
    
    //step 2: 打开文件连接通道
    ret = avio_open2(&avFormatContext->pb, //avio_open2 根据url 创建和初始化AVIOContext  在使用完后一定要销毁 avio_close()
                     accFilePath,
                     AVIO_FLAG_WRITE,   //权限
                     nullptr,
                     nullptr);
    /** AVIOContext 输入输出流上下文
     * AVIOContext是FFmpeg管理输入输出数据的结构体
     * 比较重要的变量:
     * unsigned char *buffer 缓存开始的位置
     * int bufffer_size 缓存大小(默认32768)
     * unsigned char *buf_ptr 当前指针读取到的位置
     * unsigned char *buf_end 缓存结束的位置
     * void *opaque: URLContext结构体
     *
     * 在解码的情况下，buffer用于存储ffmpeg读入的数据。 example:打开一个视频文件的时候，先把数据从硬盘读入buffer 然后再送给解码器用于解码
     *
     * opaque指向了URLContext ---每种协议(rtp, rtmp, file...)对应一个URLProtocol
     */
    if (ret != 0) {
        LOGI("Could not avio open faile %s", av_err2str(ret));
        return -1;
    }
    //通过上面两步可以确定出Muxer与Protocol
    
    //step 3:分配Codec的相关内容
    this->alloc_audio_stream(codec_name);
    av_dump_format(avFormatContext, 0, accFilePath, 1);
    
    //将音频文件的头部信息写入
    if (avformat_write_header(avFormatContext, nullptr) != 0) {
        LOGI("Could not write header\n");
        return -1;
    }
    
    //写入成功后做好标记，写入尾部av_write_trailer 如果没有写入头部，直接写入尾部的话，会crash掉
    this->isWriteHeaderSuccess = true;
    this->alloc_avframe();
    return 1;
}

int AudioEncoder::init(int bitRate, int channels, int bitsPerSample, const char *aacFilePath, const char *codec_name    ){
    return init(bitRate, channels, 44100, bitsPerSample, aacFilePath, codec_name);
}

void AudioEncoder::encode(uint8_t *buffer, int size){
    int bufferCursor = 0;
    int bufferSize = size;
    while (bufferSize >= (buffer_size - samplesCursor)) {
        int cpySize = buffer_size - samplesCursor; //每一帧的大小  buffer_size - samplesCursor
        memcpy(samples + samplesCursor, buffer + bufferCursor, cpySize);
        bufferCursor += cpySize;
        bufferSize -= cpySize;
        this->encodePacket();
        samplesCursor = 0;
    }
    
    if (bufferSize > 0) {
        memcpy(samples + samplesCursor, buffer +bufferCursor, bufferSize);
        samplesCursor += bufferSize;
    }
}

void AudioEncoder::encodePacket(){
    int ret;
    AVPacket pkt;
    AVFrame *encode_frame;
    
    //重采样
    if (swrContext) {
        swr_convert(swrContext,
                    convert_data,
                    avCodecContext->frame_size,
                    (const uint8_t **)input_frame->data,
                    avCodecContext->frame_size);
        
        int length = avCodecContext->frame_size * av_get_bytes_per_sample(avCodecContext->sample_fmt);
        for (int k = 0; k < 2; ++ k) {   //AVFrame中的data [0][1]
            for (int j = 0; j < length; ++j) {
                swrFrame->data[k][j] = convert_data[k][j];
            }
        }
        encode_frame = swrFrame;
    } else {
        encode_frame = input_frame;
    }
    
    av_init_packet(&pkt);
    pkt.stream_index = 0;
    pkt.duration = (int)AV_NOPTS_VALUE;
    pkt.pts = pkt.dts = 0;
    pkt.data = samples; //把从pcm文件中读取到的数据赋值给packet  其实就是一帧数据
    pkt.size = buffer_size;
    
    
    
    //进行编码
    /*ret = avcodec_encode_audio2(avCodecContext, &pkt, encode_frame, &got_output);
    if (ret < 0) {
        LOGI("Error encoding audio frame\n");
        return;
    }
    
    if (got_output) {
        if (avCodecContext->coded_frame && avCodecContext->coded_frame->pts != AV_NOPTS_VALUE) {
            pkt.pts = av_rescale_q(avCodecContext->coded_frame->pts, avCodecContext->time_base, audioStream->time_base);
        }
        
        pkt.flags |= AV_PKT_FLAG_KEY;
        this->duration = pkt.pts * av_q2d(audioStream->time_base);
        
        //此函数负责交错的输出一个媒体包，如果调用者无法保证来自各个媒体流的包正确交流，则最好调用此函数输出媒体包，反之，可以调用av_write_frame以提高性能
         av_interleaved_write_frame(avFormatContext, &pkt);
    }
    
    av_free_packet(&pkt);*/
    
    ret = avcodec_send_frame(avCodecContext, encode_frame);
    if (ret < 0) {
        LOGI("Error encoding audio frame\n");
    } else {
        ret = avcodec_receive_packet(avCodecContext, &pkt);
        if (ret == 0) {
            pkt.flags |= AV_PKT_FLAG_KEY;
            this->duration = pkt.pts * av_q2d(audioStream->time_base); //
            //此函数负责交错的输出一个媒体包，如果调用者无法保证来自各个媒体流的包正确交流，则最好调用此函数输出媒体包，反之，可以调用av_write_frame以提高性能
             av_interleaved_write_frame(avFormatContext, &pkt);
        }
    }
    av_packet_unref(&pkt);
}


void AudioEncoder::destroy(){
    LOGI("start destory");
    
    //这里需要判断是否删除resampler(重采样音频格式、声道，采样率等)相关资源
    if (nullptr != swrBuffer) {
        free(swrBuffer);
        swrBuffer = nullptr;
        swrBufferSize = 0;
    }
    
    if (nullptr != swrContext) {
        swr_free(&swrContext);
        swrContext = nullptr;
    }
    
    if (convert_data) {
        av_freep(&convert_data);
        free(convert_data);
    }
    
    if (nullptr != swrFrame) {
        av_frame_free(&swrFrame);
    }
    
    if (nullptr != samples) {
        av_freep(&samples);
    }

    if (nullptr != input_frame) {
        av_frame_free(&input_frame);
    }
    
    if (this->isWriteHeaderSuccess) {
        avFormatContext->duration = this->duration * AV_TIME_BASE;
        LOGI("duration is %.3f", this->duration);
        av_write_trailer(avFormatContext);
    }
    
    if (nullptr != avCodecContext) {
        avcodec_close(avCodecContext);
        av_free(avCodecContext);
    }
    
    //关闭AVIOContext
    if (nullptr != avCodecContext && nullptr != avFormatContext->pb) {
        avio_close(avFormatContext->pb);
    }
    LOGI("end destroy !!! totalEncodeTimeMills is %d total SWRTimeMills is %d", totalEncodeTimeMills, totalSWRTimeMills);
}



