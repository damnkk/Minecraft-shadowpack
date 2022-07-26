#version 120
varying vec4 texcoord;
void main() {
// 为归一化的裁剪空间坐标赋值
gl_Position = ftransform();
// 得到当前坐标在0号纹理(即输入图像)上的坐标
texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
}