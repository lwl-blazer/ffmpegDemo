#ifndef XDECODE_H
#define XDECODE_H

#include<mutex>

struct AVCodecParameters;
struct AVCodecContext;
struct AVPacket;
struct AVFrame;

class Xdecode
{
public:
    Xdecode();
    virtual ~Xdecode();

    //函数内部负责释放AVCodecParameters
    virtual bool open(AVCodecParameters *para);
    virtual bool send(AVPacket *pkt);
    virtual AVFrame* recv();

    virtual void close();
    virtual void clear();

protected:
    AVCodecContext *codec = nullptr;   //视频解码的上下文 包含解码器
    std::mutex mux;
};

#endif // XDECODE_H
