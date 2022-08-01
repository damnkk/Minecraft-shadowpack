#version 120

const int shadowMapResolution = 1024;   // 阴影分辨率 默认 1024
const float	sunPathRotation	= -40.0;    // 太阳偏移角 默认 0

uniform sampler2D texture;
uniform sampler2D depthtex0;
uniform sampler2D shadow;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;

uniform int worldTime;
uniform ivec2 eyeBrightnessSmooth;

uniform vec3 sunPosition;//两者分别代表太阳和月亮在眼坐标系中的坐标
uniform vec3 moonPosition;

uniform float far;
uniform float viewWidth;
uniform float viewHeight;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

varying float isNight;

varying vec4 texcoord;
varying vec3 mySkyColor;
varying vec3 mySunColor;

vec2 getFishEyeCoord(vec2 positionInNdcCoord) {
    return positionInNdcCoord / (0.15 + 0.85*length(positionInNdcCoord.xy));
}

/*
 * @function getShadow         : getShadow 渲染阴影
 * @param color                : 原始颜色
 * @param positionInWorldCoord : 该点在世界坐标系下的坐标
 * @return                     : 渲染阴影之后的颜色
 */
vec4 getShadow(vec4 color, vec4 positionInWorldCoord) {
    // 我的世界坐标 转 太阳的眼坐标
    vec4 positionInSunViewCoord = shadowModelView * positionInWorldCoord;
    // 太阳的眼坐标 转 太阳的裁剪坐标
    vec4 positionInSunClipCoord = shadowProjection * positionInSunViewCoord;
    // 太阳的裁剪坐标 转 太阳的ndc坐标
    vec4 positionInSunNdcCoord = vec4(positionInSunClipCoord.xyz/positionInSunClipCoord.w, 1.0);

    positionInSunNdcCoord.xy = getFishEyeCoord(positionInSunNdcCoord.xy);

    // 太阳的ndc坐标 转 太阳的屏幕坐标
    vec4 positionInSunScreenCoord = positionInSunNdcCoord * 0.5 + 0.5;

    float currentDepth = positionInSunScreenCoord.z;    // 当前点的深度
    float dis = length(positionInWorldCoord.xyz) / far;

    /*
    float closest = texture2D(shadow, positionInSunScreenCoord.xy).x; 
    // 如果当前点深度大于光照图中最近的点的深度 说明当前点在阴影中
    if(closest+0.0001 <= currentDepth && dis<0.99) {
        color.rgb *= 0.5;   // 涂黑
    }
    */


    float isNight = texture2D(colortex3,texcoord.st).x;
    
    int radius = 1;
    float sum = pow(radius*2+1, 2);
    float shadowStrength = 0.6 * (1-dis)*(1-0.6*isNight);
    for(int x=-radius; x<=radius; x++) {
        for(int y=-radius; y<=radius; y++) {
            // 采样偏移
            vec2 offset = vec2(x,y) / shadowMapResolution;
            // 光照图中最近的点的深度
            float closest = texture2D(shadow, positionInSunScreenCoord.xy + offset).x;   
            // 如果当前点深度大于光照图中最近的点的深度 说明当前点在阴影中
            if(closest+0.001 <= currentDepth && dis<0.99) {
                sum -= 1; // 涂黑
            }
        }
    }
    sum /= pow(radius*2+1, 2);
    color.rgb *= sum*shadowStrength + (1-shadowStrength);  
    
    return color;
}

/* 
 *  @function getBloomOriginColor : 亮色筛选
 *  @param color                  : 原始像素颜色
 *  @return                       : 筛选后的颜色
 */
vec4 getBloomOriginColor(vec4 color) {
    float brightness = 0.299*color.r + 0.587*color.g + 0.114*color.b;
    if(brightness < 0.5) {
        color.rgb = vec3(0);
    }
    color.rgb *= (brightness-0.5)*2;
    return color;
}

/* 
 *  @function getBloom : 亮色筛选
 *  @return            : 泛光颜色
 */
vec3 getBloom() {
    int radius = 15;
    vec3 sum = vec3(0);
    
    for(int i=-radius; i<=radius; i++) {
        for(int j=-radius; j<=radius; j++) {
            vec2 offset = vec2(i/viewWidth, j/viewHeight);
            sum += getBloomOriginColor(texture2D(texture, texcoord.st+offset)).rgb;
        }
    }
    
    sum /= pow(radius+1, 2);
    return sum*0.3;
}

/*
* @function drawSky : 天空绘制
* @param color : 原始颜色
* @param positionInViewCoord : 眼坐标
* @param positionInWorldCoord : 我的世界坐标
* @return : 绘制天空后的颜色
*/
vec3 drawSky(vec3 color,vec4 positionInViewCoord,vec4 positionInWorldCoord)
{
    float dis = length(positionInWorldCoord.xyz) / far;

    //眼坐标系中的点到太阳的距离
    float disToSun = 1.0-dot(normalize(positionInViewCoord.xyz),normalize(sunPosition));//1-cosx = 2sin^2(x/2)实际上也不是那种准确的距离
    float disToMoon = 1.0-dot(normalize(positionInViewCoord.xyz),normalize(moonPosition));//就是和真实距离具有相关性即可,我们再调出实际效果即可

    //绘制圆形太阳
    vec3 drawSun = vec3(0);
    if(disToSun<0.005&&dis>0.999)//注意是两个条件,是否在太阳的范围,是否是天空
    {
        drawSun = mySunColor*2 * (1.0-isNight);
    }
    //绘制圆形月亮
    vec3 drawMoon = vec3(0);
    if(disToMoon<0.005&&dis>0.999)
    {
        drawMoon = mySunColor*2 ;
    }
    vec3 finalColor = mySkyColor;
    
    //雾和太阳颜色混合
    float sunMixFactor = clamp(1.1-disToSun,0,1)* (1.0-isNight);
    finalColor = mix(finalColor,mySunColor,pow(sunMixFactor,4))*0.752;

    //雾和月亮颜色混合
    float MoonMixFactor = clamp(1.0-disToMoon,0,1) * isNight;
    finalColor = mix(finalColor,mySunColor,pow(MoonMixFactor,4));
    //finalColor*=vec3(normalize(abs(positionInWorldCoord.y-40)));
    if(positionInWorldCoord.y-80<=0)
    {
        //finalColor = mix(finalColor,vec3(0.6667, 0.8784, 1.0),abs(positionInWorldCoord.y-60)/70);
        finalColor = mix(finalColor,vec3(0.0706, 0.1647, 0.2196)*(1+6*(1-isNight)),abs(positionInWorldCoord.y-80)/70);
        //finalColor = mix(finalColor,vec3(0.6667, 0.8784, 1.0),0.13);
    }

    return mix(color,finalColor,clamp(pow(dis,7),0,1))+drawSun +drawMoon;//天空本身颜色加上太阳或月亮颜色
    //return finalColor+drawMoon+drawSun;
}

vec4 getBloomSource(vec4 color)//这个应该会写
{
    //绘制泛光
    vec4 bloom  = color;
    float id = texture2D(colortex2,texcoord.st).x;
    float brightness = dot(bloom.rgb,vec3(0.2125, 0.7154, 0.0721));
    //发光方块 一律泛光
    if(id==10089)
    {
        bloom.rgb*=2*vec3(2,1,1);
    }
    //火把 
    else if( id == 10090)
    {
        if(brightness<0.5)
        {
            bloom.rgb = vec3(0);
        }
        bloom.rgb*= 25*pow(brightness,2);
        //bloom.rgb = vec3(0.2125, 0.7154, 0.0721);
    }
    //其他方块
    else 
    {
        //bloom.rgb *= brightness;
        bloom.rgb = vec3(0);
        //bloom.rgb = pow(bloom.rgb,vec3(1.0));
    }
    return bloom;
}

/* DRAWBUFFERS: 01 */
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

    // 计算泛光
    //color.rgb += getBloom();

    // 绘制阴影
    float id = texture2D(colortex2,texcoord.st).x;//知道了这个顶点的材质ID
    if(id!=10089&&id!=10090)//不是两种发光物,才绘制阴影
    {
        color = getShadow(color, positionInWorldCoord);
    }

     //color.rgb = pow(color.rgb,vec3(1/1.5));
     //color.rgb*=vec3(0.499,0.527,0.114);
    int hour = worldTime/1000;
    int next = (hour+1<24)?(hour+1):(0);//形成了一个循环
    float delta = float(worldTime-hour*1000)/1000;


    color.xyz = drawSky(color.xyz,positionInViewCoord,positionInWorldCoord);

    
    gl_FragData[0] = color;
    gl_FragData[1] = getBloomSource(color);
}