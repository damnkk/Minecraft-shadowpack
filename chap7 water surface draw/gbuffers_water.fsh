#version 120

uniform sampler2D texture;
varying vec4 texcoord;
uniform int worldTime;
varying vec4 color;
varying float id;
varying vec3 mySkyColor;
varying vec3 normal;
varying vec4 positionInViewCoord;
const int noiseTextureResolution = 128;
uniform mat4 gbufferModelViewInverse;
uniform sampler2D noisetex;
uniform vec3 cameraPosition;

/*
* @function getWave : 绘制水面纹理
* @param color : 原水面颜色
* @param positionInWorldCoord : 世界坐标（绝对坐标）
* @return : 叠加纹理后的颜色
*/
vec3 getWave(vec3 color ,vec4 positionInworldCoord)
{
    //小波浪
    float speed1 = float(worldTime)/(noiseTextureResolution*15);
    vec3 coord1 = positionInworldCoord.xyz/noiseTextureResolution;
    coord1.x *=3;
    coord1.x +=speed1;//水平面是一个恒平面,因此根据恒平面坐标在噪声纹理中采样
    coord1.z +=speed1*0.2;
    float noise1 = texture2D(noisetex,coord1.xz).x;
    //混合波浪
    float speed2 = float(worldTime)/(noiseTextureResolution*7);
    vec3 coord2 = positionInworldCoord.xyz/noiseTextureResolution;
    coord2.x *=0.5;
    coord2.x -= speed2 *0.15+noise1*0.05;
    coord2.z -= speed2*0.7-noise1*0.05; 
    float noise2 = texture2D(noisetex,coord2.xz).x;

    //绘制"纹理
    color *= noise2*0.6+0.4;
    return color;
}

void main()
{ 
    if(id==20)
    {
        gl_FragData[0] = color;
        return;
    }
    float cosine = dot(normalize(positionInViewCoord.xyz),normalize(normal));
    cosine = clamp(abs(cosine),0,1);
    float factor = pow(1.0-cosine,4);
    vec4 positionInWorldCoord = gbufferModelViewInverse* positionInViewCoord;
    positionInWorldCoord.xyz +=cameraPosition;
    vec3 finalColor = mySkyColor;
    finalColor = getWave(mySkyColor,positionInWorldCoord);
    gl_FragData[0] = vec4(mix(mySkyColor*0.3,finalColor,factor),0.75);
}