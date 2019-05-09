#include "widget.h"

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
}


void Widget::paintGL(){

}

void Widget::resizeGL(int w, int h){

}
