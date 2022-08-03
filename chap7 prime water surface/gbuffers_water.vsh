#version 120

attribute vec2 mc_Entity;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;

uniform int worldTime;

varying float id;

varying vec3 mySkyColor;
varying vec3 normal;

varying vec4 texcoord;
varying vec4 color;
varying vec4 positionInViewCoord;

vec3 skyColorArr[24] = vec3[24](
vec3(0.1, 0.6, 0.9), // 0-1000
vec3(0.1, 0.6, 0.9), // 1000 - 2000
vec3(0.1, 0.6, 0.9), // 2000 - 3000
vec3(0.1, 0.6, 0.9), // 3000 - 4000
vec3(0.1, 0.6, 0.9), // 4000 - 5000
vec3(0.1, 0.6, 0.9), // 5000 - 6000
vec3(0.1, 0.6, 0.9), // 6000 - 7000
vec3(0.1, 0.6, 0.9), // 7000 - 8000
vec3(0.1, 0.6, 0.9), // 8000 - 9000
vec3(0.1, 0.6, 0.9), // 9000 - 10000
vec3(0.1, 0.6, 0.9), // 10000 - 11000
vec3(0.1, 0.6, 0.9), // 11000 - 12000
vec3(0.1, 0.6, 0.9), // 12000 - 13000
vec3(0.02, 0.2, 0.27), // 13000 - 14000
vec3(0.02, 0.2, 0.27), // 14000 - 15000
vec3(0.02, 0.2, 0.27), // 15000 - 16000
vec3(0.02, 0.2, 0.27), // 16000 - 17000
vec3(0.02, 0.2, 0.27), // 17000 - 18000
vec3(0.02, 0.2, 0.27), // 18000 - 19000
vec3(0.02, 0.2, 0.27), // 19000 - 20000
vec3(0.02, 0.2, 0.27), // 20000 - 21000
vec3(0.02, 0.2, 0.27), // 21000 - 22000
vec3(0.02, 0.2, 0.27), // 22000 - 23000
vec3(0.02, 0.2, 0.27) // 23000 - 24000(0)
);
/*
* @function getBump : 水面凹凸计算
* @param positionInViewCoord : 眼坐标系中的坐标
* @return : 计算凹凸之后的眼坐标
*/
vec4 getBump(vec4 positionInViewCoord)
{
    vec4 positionInWorldCoord = gbufferModelViewInverse*positionInViewCoord;
    positionInWorldCoord.xyz +=cameraPosition;

    //计算凹凸
    positionInWorldCoord.y +=sin(float(worldTime*0.3)+positionInWorldCoord.z*2)*0.05+sin(float(worldTime*0.3)+positionInWorldCoord.x*2)*0.05;

    positionInWorldCoord.xyz -=cameraPosition;//这里我们知道了,我的世界坐标就是真正的世界坐标+摄像机坐标(小人坐标)
    return gbufferModelView*positionInWorldCoord;

}

void main()
{

    int hour = worldTime/1000;
    int next = (hour+1<24)?(hour+1):(0);
    float delta = float(worldTime-hour*1000)/1000;
    positionInViewCoord = gl_ModelViewMatrix*gl_Vertex;
    //gl_Position = gbufferProjection * positionInViewCoord;
    gl_Position = gbufferProjection * getBump(positionInViewCoord); // p变换
    
    color = gl_Color;
    texcoord = gl_TextureMatrix[0]*gl_MultiTexCoord0;
    id = mc_Entity.x;
    mySkyColor = mix(skyColorArr[hour],skyColorArr[next],delta);
    normal = gl_NormalMatrix*gl_Normal;
}