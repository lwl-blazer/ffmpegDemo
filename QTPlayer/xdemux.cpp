#include "xdemux.h"

#include <iostream>

extern "C" {
#include<libavformat/avformat.h>
}

#pragma comment(lib, "avformat.lib")
#pragma comment(lib, "avutil.lib")
#pragma comment(lib, "avcodec.lib")

using namespace std;

XDemux::XDemux()
{
    /*
NULL -- 在C++中是有二义性的
nullptr 是一个关键字，表示一个空指针  也是解决NULL的问题
*/

    /*
C++类型转换:
static_cast<type-id>(exdivssion) 该运算符把exdivssion转换为type-id类型，但没有运行时类型检查来保证转换的安全性   安全性由开发人员来保证

dynamic_cast<type-id>(exdivssion) type-id 必须是类的指针，类的引用或者void *   主要用于类之间的转换 具有类型检查功能

reindivter_cast<type-id>(exdivssion)  type-id 必须是一个指针、引用、算术类型、函数指针或者成员指针  它可以把一个指针转换整数，也可以把整数转换成指针 用法最广

const_cast<type-id>(exdivssion) 用来修改类型的const 或 volatile属性
*/

    static bool isFirst = true;
    static std::mutex dmux;
    dmux.lock();
    if (isFirst) {
        av_register_all();
        avformat_network_init();
        isFirst = false;
    }
    dmux.unlock();
}

static double r2d(AVRational r){
    return r.den == 0 ? 0 : (double)r.num / (double)r.den;
}

bool XDemux::Open(const char *url){
    close();

    AVDictionary *opts = nullptr;
    av_dict_set(&opts, "rtsp_transport", "tcp", 0);
    av_dict_set(&opts, "max_delay", "500", 0);

    mux.lock(); //互斥锁(尽量晚锁，尽量早释放)

    //avformat_open_input  用于打开多媒体数据并且获得一些相关的信息   内部打开输入视频数据并且探测视频的格式  赋值AVFormatContext中的AVInputFormat
    int ret = avformat_open_input(&ic,
                                  url,
                                  nullptr,
                                  &opts); //通过avformat_open_input接口将input_filename句柄挂载至ic结构里，之后FFmpeg即可对ic进行操作
    if (ret != 0) {
        mux.unlock();
        char buf[1024] = {0};
        av_strerror(ret, buf, sizeof (buf) - 1);
        cout << "open" << url << "failed!:" << buf << endl;
        return false;
    }

    cout << "open" << url << "success" << endl;

    //从AVFormatContext中建立输入文件对应的流信息
    ret = avformat_find_stream_info(ic, nullptr);    //查找音视频流信息

    int totalMs = static_cast<int>(ic->duration / (AV_TIME_BASE/1000));
    cout << "totalMs:" << totalMs <<endl;

    av_dump_format(ic, 0, url, 0);

    //可以用遍历获取音视频stream_index， 也要以用这个方法
    videoStream = av_find_best_stream(ic,
                                      AVMEDIA_TYPE_VIDEO,
                                      -1,
                                      -1,
                                      nullptr,
                                      0);
    //音视频流
    AVStream *as = ic->streams[videoStream];
    width = as->codecpar->width;
    height = as->codecpar->height;
    cout << "=======================================================" << endl;
    cout << "codec_id = " << as->codecpar->codec_id << endl;
    cout << "format = " << as->codecpar->format << endl;
    cout << "width=" << as->codecpar->width << endl;
    cout << "height=" << as->codecpar->height << endl;
    cout << "video fps = " << r2d(as->avg_frame_rate) << endl;


    cout << "=======================================================" << endl;
    //音频stream_index
    audioStream = av_find_best_stream(ic,
                                      AVMEDIA_TYPE_AUDIO,
                                      -1,
                                      -1,
                                      nullptr,
                                      0);
    as = ic->streams[audioStream]; //音频流
    cout << "codec_id = " << as->codecpar->codec_id << endl;
    cout << "format = " << as->codecpar->format << endl;
    cout << "sample_rate = " << as->codecpar->sample_rate << endl;
    cout << "channels = " << as->codecpar->channels << endl;
    cout << "frame_size = " << as->codecpar->frame_size << endl;
    //1024 * 2 * 2 = 4096  fps = sample_rate/frame_size
    mux.unlock();

    return true;
}

//从把AVFormatContext的所有流读到AVPacket中
AVPacket *XDemux::Read(){
    mux.lock();

    if (!ic) {
        mux.unlock();
        return nullptr;
    }

    AVPacket *pkt = av_packet_alloc();

    //读取音视频流   从AVFormatContext中读取音视频流数据包， 将音视频流数据包读取出来存储至AVPacket中,然后通过对AVPacket包判断，确定其为音频、视频、字幕数据，最后进行解码或者进行数据存储
    int ret = av_read_frame(ic, pkt);
    if (ret != 0) {
        mux.unlock();
        av_packet_free(&pkt);
        return nullptr;
    }

    //转换成毫秒
    pkt->pts = pkt->pts * (1000 * r2d(ic->streams[pkt->stream_index]->time_base));
    pkt->dts = pkt->dts * (1000 * r2d(ic->streams[pkt->stream_index]->time_base));
    mux.unlock();

    cout <<"pts:" << pkt->pts << "" <<endl << flush;
    return pkt;
}

AVCodecParameters *XDemux::copyVideoParameters(){
    mux.lock();
    if (!ic) {
        mux.unlock();
        return nullptr;
    }

    /* 注意事项:
     * 为什么AVCodecParameters需要alloc而不是直接用指针引用  因为在解码的时候需要用的uint8_t *extradata的值，在被释放的时候也会同时被释放，
     * 所以需要alloc出空间，然后进行copy操作
     */
    AVCodecParameters *pa = avcodec_parameters_alloc();
    avcodec_parameters_copy(pa, ic->streams[videoStream]->codecpar);
    mux.unlock();
    return pa;
}

AVCodecParameters *XDemux::copyAudioParameters(){
    mux.lock();
    if (!ic) {
        mux.unlock();
        return nullptr;
    }

    AVCodecParameters *pa = avcodec_parameters_alloc();
    avcodec_parameters_copy(pa, ic->streams[audioStream]->codecpar);
    mux.unlock();
    return pa;
}


bool XDemux::seek(double pos){

    mux.lock();
    if (!ic) {
        mux.unlock();
        return false;
    }
    //清理读取缓存  一般读文件的时候没有，读文件流的时候肯定是有的，如果不清除可能会出现粘包现象
    avformat_flush(ic);

    long long seekPos = 0;
     //seek的位置计算  有三种情况的判断
    //timestamp  先基于AVStream的duration来计算 如果为空那再基于AVStream中的time_base 如果空基于AV_TIME_BASE(1000000)
    seekPos = static_cast<long long>(ic->streams[videoStream]->duration * pos);

    int ret = av_seek_frame(ic, videoStream, seekPos, AVSEEK_FLAG_BACKWARD|AVSEEK_FLAG_FRAME); //flags 往后跳到关键帧

    mux.unlock();
    return  ret >= 0 ? true : false;
}


bool XDemux::isAudio(AVPacket *pkt){
    if (!pkt) {
        return false;
    }

    if (pkt->stream_index == videoStream) {
        return  false;
    }
    return true;
}

void XDemux::clear(){
    mux.lock();
    if (!ic) {
        mux.unlock();
        return;
    }

    avformat_flush(ic);
    mux.unlock();
}

void XDemux::close(){
    mux.lock();
    if (!ic) {
        mux.unlock();
        return;
    }

    avformat_close_input(&ic); //执行结束操作主要为关闭输入文件以及释放资源等
    totalMs = 0;
    mux.unlock();
}


XDemux::~XDemux(){

}

