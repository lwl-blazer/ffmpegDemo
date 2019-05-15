#include "widget.h"
#include <QOpenGLShaderProgram>
#include <iostream>

#include <QDebug>


extern "C" {
#include <libavutil/frame.h>
}

using namespace std;

Widget::Widget(QWidget *parent)
    : QOpenGLWidget(parent)
{
}

Widget::~Widget()
{

}

void Widget::Repaint(AVFrame *frame){
    if (!frame) {
        return;
    }
    mux.lock();
    if (!datas[0] || width * height == 0 || frame->width != this->width || frame->height != this->height) {
        av_frame_free(&frame);
        mux.unlock();
        return;
    }

    memcpy(datas[0], frame->data[0], width * height);
    memcpy(datas[1], frame->data[1], width * height/4);
    memcpy(datas[2], frame->data[2], width * height/4);

    mux.unlock();
    update();
}


void Widget::Init(int width, int height){
    mux.lock();
    this->width = width;
    this->height = height;

    delete datas[0];
    delete datas[1];
    delete datas[2];

    datas[0] = new unsigned char[width * height];
    datas[1] = new unsigned char[width * height / 4];
    datas[2] = new unsigned char[width * height / 4];

    //删除纹理
    if (texs[0]) {
        glDeleteTextures(3, texs);
    }

    glGenTextures(3, texs);

    glBindTexture(GL_TEXTURE_2D, texs[0]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, width, height, 0, GL_RED, GL_UNSIGNED_BYTE, 0);


    glBindTexture(GL_TEXTURE_2D, texs[1]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, width/2, height/2, 0, GL_RED,  GL_UNSIGNED_BYTE, 0);

    glBindTexture(GL_TEXTURE_2D, texs[2]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, width/2, height/2, 0, GL_RED,  GL_UNSIGNED_BYTE, 0);

    mux.unlock();

    qDebug() << "Init(w, h)";
}





void Widget::initializeGL(){

    qDebug() << "initializeGL";
    mux.lock();
    initializeOpenGLFunctions();
    initShader();
    mux.unlock();
}

void Widget::initShader(){
    program = new QOpenGLShaderProgram;

    //compile
    if (!program->addShaderFromSourceFile(QOpenGLShader::Vertex, ":/vshader.vsh")){
        close();
    }

    if (!program->addShaderFromSourceFile(QOpenGLShader::Fragment, ":/fshader.fsh")) {
        close();
    }

    if(!program->link()){
        close();
    }

    if(!program->bind()){
        close();
    }
    cout << "init shader success" << endl;

    int a_ver = program->attributeLocation("vertexIn");
    int t_ver = program->attributeLocation("textureIn");

    static const GLfloat ver[] = {
        -1.0, -1.0,
         1.0, -1.0,
        -1.0,  1.0,
         1.0,  1.0
    };

    static const GLfloat tex[] = {
        0.0, 1.0,
        1.0, 1.0,
        0.0, 0.0,
        1.0, 0.0
    };

    glVertexAttribPointer(a_ver, 2, GL_FLOAT, 0, 0, ver);
    glEnableVertexAttribArray(a_ver);

    glVertexAttribPointer(t_ver, 2, GL_FLOAT, 0, 0, tex);
    glEnableVertexAttribArray(t_ver);

    unis[0] = program->uniformLocation("tex_y");
    unis[1] = program->uniformLocation("tex_u");
    unis[2] = program->uniformLocation("tex_v");

}


void Widget::paintGL(){
    //glClearColor(1.0, 0.0, 1.0, 1);
    /*glClear(GL_COLOR_BUFFER_BIT);


    arrayBuf.bind();
    //没有使用 glUseProgram()
    glDrawArrays(GL_TRIANGLES, 0, 3);*/

    mux.lock();

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texs[0]);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height, GL_RED, GL_UNSIGNED_BYTE, datas[0]);
    glUniform1i(unis[0], 0);

    glActiveTexture(GL_TEXTURE0 + 1);
    glBindTexture(GL_TEXTURE_2D, texs[1]);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width/2, height/2, GL_RED, GL_UNSIGNED_BYTE, datas[1]);
    glUniform1i(unis[1], 1);

    glActiveTexture(GL_TEXTURE0+2);
    glBindTexture(GL_TEXTURE_2D, texs[2]);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width/2, height/2, GL_RED, GL_UNSIGNED_BYTE, datas[2]);
    glUniform1i(unis[2], 2);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    qDebug() << "paint GL";
    mux.unlock();
}

void Widget::resizeGL(int w, int h){
    mux.lock();
    qDebug() << "resizeGL " << width << ":" << height;
    mux.unlock();
}
