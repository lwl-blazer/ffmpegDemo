#include "widget.h"
#include <QApplication>

#include <QLabel>
#include <QSurfaceFormat>

int main(int argc, char *argv[])
{
    QApplication a(argc, argv);

    QSurfaceFormat format;
    format.setDepthBufferSize(24);
    QSurfaceFormat::setDefaultFormat(format);

    a.setApplicationName("OpenGL TEST");
    a.setApplicationVersion("0.1");
#ifndef QT_NO_OPENGL
    Widget widget;
    widget.resize(900, 600);
    widget.show();

#else
    QLabel note("OpenGL Support required");
    note.show();
#endif

    return a.exec();
}
