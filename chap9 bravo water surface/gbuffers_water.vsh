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

varying vec4 lightMapCoord;
varying vec4 texcoord;
varying vec4 color;
varying vec4 positionInViewCoord;

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

    positionInWorldCoord.xyz -=cameraPosition;//这里我们知道了,我的世界坐标就是真正的世界坐标-摄像机坐标(小人坐标)
    return gbufferModelView*positionInWorldCoord;

}

void main()
{

    positionInViewCoord = gl_ModelViewMatrix*gl_Vertex;
    //gl_Position = gbufferProjection * positionInViewCoord;
    gl_Position = gbufferProjection * getBump(positionInViewCoord); // p变换
    
    color = gl_Color;
    texcoord = gl_TextureMatrix[0]*gl_MultiTexCoord0;
    lightMapCoord = gl_TextureMatrix[1]*gl_MultiTexCoord1;
    id = mc_Entity.x;
    normal = gl_NormalMatrix*gl_Normal;
}