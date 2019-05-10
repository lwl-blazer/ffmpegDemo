#include "widget.h"
#include <QOpenGLShaderProgram>
#include <iostream>

using namespace std;

Widget::Widget(QWidget *parent)
    : QOpenGLWidget(parent)
{
}

Widget::~Widget()
{

}

void Widget::initializeGL(){
    initializeOpenGLFunctions();
    initShader();
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

    //顶点缓冲数组
    arrayBuf.create();
    QVector3D vertexs[] = {QVector3D(-0.5, -0.5f, 0.0),
                           QVector3D(0.5, -0.5, 0.0),
                           QVector3D(0.0, 0.5, 0.0)};
    arrayBuf.bind();
    arrayBuf.allocate(vertexs, 3 * sizeof(QVector3D));

    int vertexLocation = program->attributeLocation("aPos");
    program->enableAttributeArray(vertexLocation);
    program->setAttributeBuffer(vertexLocation, GL_FLOAT, 0, 3, 0);
}


void Widget::paintGL(){
    glClearColor(1.0, 0.0, 1.0, 1);
    glClear(GL_COLOR_BUFFER_BIT);


    arrayBuf.bind();
    //没有使用 glUseProgram()
    glDrawArrays(GL_TRIANGLES, 0, 3);
}

void Widget::resizeGL(int w, int h){

}
