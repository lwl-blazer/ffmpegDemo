#include "xdecode.h"
#include <iostream>

extern "C"{
#include<libavcodec/avcodec.h>
}

using namespace std;

Xdecode::Xdecode()
{

}


Xdecode::~Xdecode(){

}


bool Xdecode::open(AVCodecParameters *para){
    if (!para) {
        return false;
    }

    close();
    //查找解码器 根据解封装出来的codec_id
    AVCodec *vcodec = avcodec_find_decoder(para->codec_id);
    if (!vcodec) {
        avcodec_parameters_free(&para);
        cout << "can't find the code_id" << para->codec_id <<endl;
        return false;
    }

    cout << "Find the AVCodec " << para->codec_id << endl;

    mux.lock();
    //根据找到的对应Decodec 申请一个AVCodecContext 然后将Decodec挂在AVCodecContext下
    codec = avcodec_alloc_context3(vcodec);

    //把AVCodecParameters参数同步至AVCodecContext中
    avcodec_parameters_to_context(codec, para);
    avcodec_parameters_free(&para); //释放parameter

    //thread_count 用于决定有多少个独立任务去执行
    codec->thread_count = 8;

    //当解码器的参数设置完毕后，打开解码器
    int ret = avcodec_open2(codec, nullptr, nullptr);
    if (ret != 0) {
        avcodec_free_context(&codec);

        mux.unlock();
        char buf[1024] = {0};
        av_strerror(ret, buf, sizeof (buf) - 1);
        cout << "avcodec_open2 failed!:" << buf << endl;
        return false;
    }

    mux.unlock();

    cout << "avcodec_open2 success!" << endl;
    return true;
}

/*
 * 老接口是使用的avcodec_decode_video2(视频解码接口) 和avcodec_decode_audio4(音频解码)
 *
 * avcodec_send_packet 和 avcodec_receive_frame调用关系并不是一对一的， 比如一些音频数据一个AVPacket中包含了1秒钟的音频，调用一次avcodec_send_packet之后，可能需要调用25次avcodec_receive才能获得全部的音频数据
*/
//发送编码数据包
bool Xdecode::send(AVPacket *pkt){

    if (!pkt || pkt->size <= 0 || !pkt->data) {
        return false;
    }

    mux.lock();
    if (!codec) {
        mux.unlock();
        return false;
    }

    int ret = avcodec_send_packet(codec, pkt);
    mux.unlock();
    av_packet_free(&pkt);
    return ret != 0 ? false : true;
}

//接收解码后的数据
AVFrame *Xdecode::recv(){

    mux.lock();
    if (!codec) {
        mux.unlock();
        return nullptr;
    }

    AVFrame *frame = av_frame_alloc();

    int ret = avcodec_receive_frame(codec, frame);

    mux.unlock();

    if (ret != 0) {
        av_frame_free(&frame);
        return nullptr;
    }

    cout << "linesize:[" << frame->linesize[0] << "]" << endl;

    cout << "view-frame-data" << frame->data << endl;

    return frame;
}

void Xdecode::clear(){
    mux.lock();
    if (codec) {
        avcodec_flush_buffers(codec);
    }
    mux.unlock();
}

void Xdecode::close(){
    mux.lock();
    if (codec) {
        //先关闭 再释放
        avcodec_close(codec);
        avcodec_free_context(&codec);
    }
    mux.unlock();
}
