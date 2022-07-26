#version 120

const float sunPathRotation = -40.0;
const int shadowMapResolution = 1024;

uniform sampler2D texture;
uniform sampler2D depthtex0;
uniform sampler2D shadow;

uniform float far;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

varying vec4 texcoord;

vec2 getFishEyeCoord(vec2 positionInNdcCoord)
{
    return positionInNdcCoord/(0.15+0.85*length(positionInNdcCoord.xy));
}
vec4 getShadow(vec4 color,vec4 positionInWorldCoord)
{
    // 阴影模型视图变换 -- 太阳视角下的眼坐标
    vec4 positionInSunViewCoord = shadowModelView * positionInWorldCoord;
    // 太阳眼坐标 --> 太阳裁剪坐标
    vec4 positionInSunClipCoord = shadowProjection * positionInSunViewCoord;
    // 太阳的裁剪坐标 --> 太阳NDC坐标
    vec4 positionInSunNdcCoord = vec4(positionInSunClipCoord.xyz/positionInSunClipCoord.w, 1.0);
    // 太阳的NDC坐标  --> 太阳的屏幕坐标
    positionInSunNdcCoord.xy = getFishEyeCoord(positionInSunNdcCoord.xy);
    vec4 positionInSunScreenCoord = positionInSunNdcCoord*0.5+0.5;

    float currentDepth = positionInSunScreenCoord.z;
    
    // float closest = texture2D(shadow,positionInSunScreenCoord.xy).x;
    // if(closest+0.001<=currentDepth)
    // {
    //     color.rgb*= 0.5;
    // }
    float dis = length(positionInWorldCoord.xyz)/far;
    int radius = 1;
    float sum = pow(radius*2+1,2);//sum是亮的格子
    float shadowStrength = 0.6*(1-dis);
    for(int x = -radius;x<=radius;++x)
    {
        for(int y = -radius;y<=radius;++y)
        {
            vec2 offset = vec2(x,y)/shadowMapResolution;
            float closest = texture2D(shadow,positionInSunScreenCoord.xy+offset).x;
            if(closest+0.001<=currentDepth&&dis<0.99)//最远的距离只有天,只要是陆地上的东西,都会小于0.99,因此我们这样一波设置就不画天空阴影了
            {
                sum -=1;
            }
        }
    }
    sum/= pow(radius*2+1,2);
    color.rgb *= sum* shadowStrength+(1-shadowStrength);
    return color;
}

/* DRAWBUFFERS: 0 */
void main() {
    //vec4 color = texture2D(shadow, texcoord.st);
    vec4 color = texture2D(texture, texcoord.st);

    float depth = texture2D(depthtex0, texcoord.st).x;
    
    // 利用深度缓冲建立带深度的ndc坐标
    vec4 positionInNdcCoord = vec4(texcoord.st*2-1, depth*2-1, 1);

    // 逆投影变换 -- ndc坐标转到裁剪坐标
    vec4 positionInClipCoord = gbufferProjectionInverse * positionInNdcCoord;

    // 透视除法 -- 裁剪坐标转到眼坐标
    vec4 positionInViewCoord = vec4(positionInClipCoord.xyz/positionInClipCoord.w, 1.0);

    // 逆 “视图模型” 变换 -- 眼坐标转 “我的世界坐标” 
    vec4 positionInWorldCoord = gbufferModelViewInverse * positionInViewCoord;
    
    
    //color = texture2D(depthtex0, texcoord.st);
    color = getShadow(color,positionInWorldCoord);
    
    gl_FragData[0] = color;
}