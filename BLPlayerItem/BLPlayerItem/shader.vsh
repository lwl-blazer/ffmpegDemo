#version 330 core

attribute vec4 vertexIn;
varying vec2 textureOut;

void main(void)
{
    gl_Position = vertexIn;
    textureOut = textureIn;
}
