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
    glClearColor(1.0, 0.0, 1.0, 1);

    initShader();
}

void Widget::initShader(){
    program = new QOpenGLShaderProgram;
    const char *vsrc =
            "attribute vec3 aPos; \n"
            "void main() { \n"
            "  gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0); \n"
            "}\n";

    //compile
   if(!program->addShaderFromSourceCode(QOpenGLShader::Vertex, vsrc)){
       close();
   }

    const char *fsrc =
            "void main() { \n"
            "  gl_FragColor = vec4(0.0, 1.0, 0.0, 1.0); \n"
            "}\n";
    if(!program->addShaderFromSourceCode(QOpenGLShader::Fragment, fsrc)){
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
    arrayBuf.bind();

    glDrawArrays(GL_TRIANGLES, 0, 3);
}

void Widget::resizeGL(int w, int h){

}
