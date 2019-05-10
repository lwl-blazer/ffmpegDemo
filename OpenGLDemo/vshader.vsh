attribute vec3 aPos;

void main(void)
{
    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
}
