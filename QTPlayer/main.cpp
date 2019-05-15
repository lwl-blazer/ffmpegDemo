#include "widget.h"
#include <QApplication>

#include <QLabel>
#include <QSurfaceFormat>


#include "xdemux.h"
#include "xdecode.h"
#include <iostream>
#include <QThread>

using namespace std;

class TestThread : public QThread
{
public:
    void Init(){
        const char *url = "http://vfx.mtime.cn/Video/2019/04/10/mp4/190410081607863991.mp4";
        //const char *url = "/Users/luowailin/Documents/Code/ffmpegDemo/QTPlayer/testVideo-1.mp4";
        cout << "demux.open " << demux.Open(url) <<endl;

        cout << "Copy video para" << demux.copyVideoParameters() << endl;
        cout << "copy audio para" << demux.copyAudioParameters() << endl;

        cout << "vdecode.Open() = " << vdecode.open(demux.copyVideoParameters()) << endl;
        cout << "adecode.Open() = " << adecode.open(demux.copyAudioParameters()) << endl;
    }

    void run(){
        for (;;) {
            AVPacket *pkt = demux.Read();
            if (demux.isAudio(pkt)){

            } else {
                vdecode.send(pkt);
                for(;;){
                    AVFrame *frame = vdecode.recv();
                    if (frame) {
                        video.Repaint(frame);
                    } else {
                        break;
                    }
                }
            }
        }
    }
    XDemux demux;
    Xdecode vdecode;
    Xdecode adecode;
    Widget video;
};


int main(int argc, char *argv[])
{
    QApplication a(argc, argv);

    QSurfaceFormat format;
    format.setDepthBufferSize(24);
    QSurfaceFormat::setDefaultFormat(format);

    a.setApplicationName("OpenGL TEST");
    a.setApplicationVersion("0.1");


    TestThread tt;
    tt.Init();

#ifndef QT_NO_OPENGL
    tt.video.show();
    tt.video.Init(tt.demux.width, tt.demux.height);
    tt.start();
#else
    QLabel note("OpenGL Support required");
    note.show();
#endif

    return a.exec();
}
