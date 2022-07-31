#version 120

uniform sampler2D texture;
varying vec4 texcoord;

void main()
{
    vec4 color = texture2D(texture,texcoord.xy);
    gl_FragData[0] = color;
}