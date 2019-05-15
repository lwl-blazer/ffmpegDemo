#ifndef XDEMUX_H
#define XDEMUX_H

#include<mutex>

struct AVPacket;
struct AVFormatContext;
struct AVCodecParameters;

/*
 * 在头文件中不要使用命名空间  (命名空间的主要作用是防止同名函数的冲突)
*/

class XDemux
{
public:
    XDemux();
    virtual ~XDemux();

    //打开媒体文件或RTMP\HTTP\RTSP流
    virtual bool Open(const char *url);
    //空间需要调用者释放，释放AVPacket对象空间和数据空间 av_packet_free
    virtual AVPacket *Read();

    //copy视频参数 调用者释放 avcodec_parameters_free()
    virtual AVCodecParameters *copyVideoParameters();

    //copy音频参数 调用者释放 avcodec_parameters_free().
    virtual AVCodecParameters *copyAudioParameters();

    //seek  pos的范围0~1.0
    virtual bool seek(double pos);

    //清除缓存
    virtual void clear();
    //关闭
    virtual void close();

    virtual bool isAudio(AVPacket *pkt);

    int totalMs = 0;
    int width = 0;
    int height = 0;

protected:
    std::mutex mux;
    AVFormatContext *ic = nullptr;   //AVFormatContext是一个句柄 也是一个主线
    int videoStream = 0;
    int audioStream = 1;
};

#endif // XDEMUX_H

/*
 * virtual 修饰的函数是虚拟函数，
 * 在基类中用virtual函数，在派生类中可以实现对基类的覆盖
*/
