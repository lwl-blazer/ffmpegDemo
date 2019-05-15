#ifndef WIDGET_H
#define WIDGET_H

#include <QOpenGLWidget>
#include <QOpenGLFunctions>
#include <mutex>

struct AVFrame;
class QOpenGLShaderProgram;
class Widget : public QOpenGLWidget, protected QOpenGLFunctions
{
    Q_OBJECT

public:
    explicit Widget(QWidget *parent = nullptr);
    ~Widget() override;

    virtual void Repaint(AVFrame *frame);
    void Init(int width, int height);

protected:
    void initializeGL() override;
    void resizeGL(int w, int h) override;
    void paintGL() override;

private:
    void initShader();

    std::mutex mux;
    QOpenGLShaderProgram *program;

    GLuint unis[3] = {0};
    GLuint texs[3] = {0};
    unsigned char *datas[3] = {nullptr};

    int width = 240;
    int height = 128;
};

#endif // WIDGET_H
