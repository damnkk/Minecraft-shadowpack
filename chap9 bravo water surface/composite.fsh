#version 120

const int shadowMapResolution = 1024;   // 阴影分辨率 默认 1024
const float	sunPathRotation	= -40.0;    // 太阳偏移角 默认 0
const int noiseTextureResolution = 128;


uniform sampler2D texture;
uniform sampler2D depthtex0;
uniform sampler2D shadow;
uniform sampler2D colortex1;//泛光
uniform sampler2D colortex2;
uniform sampler2D colortex3;//室内室外光线纹理
uniform sampler2D colortex4;
uniform sampler2D noisetex;
uniform sampler2D depthtex1;
uniform sampler2D shadowtex1;
uniform vec3 cameraPosition;

uniform int worldTime;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

uniform vec3 sunPosition;//两者分别代表太阳和月亮在眼坐标系中的坐标
uniform vec3 moonPosition;

uniform float far;
uniform float near;
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
varying vec3 normal;

vec2 getFishEyeCoord(vec2 positionInNdcCoord) {
    return positionInNdcCoord / (0.15 + 0.85*length(positionInNdcCoord.xy));
}

/*
 * @function getShadow         : getShadow 渲染阴影
 * @param color                : 原始颜色
 * @param positionInWorldCoord : 该点在世界坐标系下的坐标
 * @return                     : 渲染阴影之后的颜色
 */
vec4 getShadow(vec4 color, vec4 positionInWorldCoord,float strength) {
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
    float shadowStrength = strength*0.6 * (1-dis)*(1-0.6*isNight);
    for(int x=-radius; x<=radius; x++) {
        for(int y=-radius; y<=radius; y++) {
            // 采样偏移
            vec2 offset = vec2(x,y) / shadowMapResolution;
            // 光照图中最近的点的深度
            float closest = texture2D( shadowtex1, positionInSunScreenCoord.xy + offset).x;//shadowtex和depthtex都是深度纹理,但一个是基于太阳屏幕的深度纹理,另一个是基于摄像机屏幕空间每个像素深度值的深度纹理   
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
/*
* @function getWave : 绘制水面纹理
* @param positionInWorldCoord : 世界坐标（绝对坐标）
* @return : 纹理亮暗系数
*/
float getWave(vec4 positionInWorldCoord)
{
    float speed1 = float(worldTime)/(noiseTextureResolution*15);
    vec3 coord1 = positionInWorldCoord.xyz/noiseTextureResolution;
    coord1.x*=3;
    coord1.x+=speed1;
    coord1.z+=speed1*0.2;
    float noise1 = texture2D(noisetex,coord1.xz).x;

    float speed2 = float(worldTime)/(noiseTextureResolution*7);
    vec3 coord2 = positionInWorldCoord.xyz/noiseTextureResolution;
    coord2.x *=0.5;
    coord2.x -=speed2*0.15+noise1*0.05;
    coord2.z -=speed2*0.7 +noise1*0.21;
    float noise2 = texture2D(noisetex,coord2.xz).x;
    return noise2*0.6+0.4;
}
/*
* @function drawSkyFakeReflect : 绘制天空的假反射
* @param positionInViewCoord : 眼坐标
* @return : 天空基色
*/
vec3 drawSkyFakeReflect(vec4 positionInViewCoord) 
{
    // 眼坐标系中的点到太阳的距离
    float disToSun = 1.0 - dot(normalize(positionInViewCoord.xyz),normalize(sunPosition)); // 太阳
    float disToMoon = 1.0 - dot(normalize(positionInViewCoord.xyz),normalize(moonPosition)); // 月亮
    // 雾和太阳颜色混合
    float sunMixFactor = clamp(1.0 - disToSun, 0, 1) * (1.0-isNight);
    vec3 finalColor = mix(mySkyColor, mySunColor, pow(sunMixFactor, 4));
    // 雾和月亮颜色混合
    float moonMixFactor = clamp(1.0 - disToMoon, 0, 1) * isNight;
    finalColor = mix(finalColor, mySunColor, pow(moonMixFactor, 4));
    return finalColor;
}

/*
* @function drawSkyFakeSun : 绘制太阳的假反射
* @param positionInViewCoord : 眼坐标
* @return : 太阳颜色
*/
vec3 drawSkyFakeSun(vec4 positionInViewCoord)
{
    // 眼坐标系中的点到太阳的距离
    float disToSun = 1.0 - dot(normalize(positionInViewCoord.xyz),normalize(sunPosition)); // 太阳
    float disToMoon = 1.0 - dot(normalize(positionInViewCoord.xyz),normalize(moonPosition)); // 月亮
    // 绘制圆形太阳
    vec3 drawSun = vec3(0);
    if(disToSun<0.005) 
    {
        drawSun = mySunColor * 2 * (1.0-isNight);
    }
    // 绘制圆形月亮
    vec3 drawMoon = vec3(0);
    if(disToMoon<0.005) 
    {
        drawMoon = mySunColor * 2 * isNight;
    }
    return drawSun + drawMoon;
}

/*
* @function rayTrace : 光线追踪计算屏幕空间反射
* @param startPoint : 光线追踪起始点
* @param direction : 反射光线方向
* @return : 反射光线碰到的方块的颜色 -- 即反射图像颜色
*/
vec3 rayTrace(vec3 startPoint,vec3 direction)
{
    vec3 point = startPoint;//测试点,首先这个起始点应该是摄像机坐标空间中的点

    //20次迭代
    int iteration = 20;
    for(int i = 0;i<iteration;++i)
    {
        point +=direction* 0.2;//一小段一小段往前走的

        //眼坐标转屏幕坐标
        vec4 positionInScreenCoord = gbufferProjection*vec4(point,1.0);//因此这里进行一次投影之后可以到裁剪空间
        positionInScreenCoord.xyz/=positionInScreenCoord.w;//这里做的齐次除法,到了NDC空间
        positionInScreenCoord.xyz = positionInScreenCoord.xyz*0.5+0.5;//变换到屏幕空间
        //剔除超出屏幕空间的射线--因为我们需要从屏幕空间中取色
        if(positionInScreenCoord.x<0||positionInScreenCoord.x>1||positionInScreenCoord.y<0||positionInScreenCoord.y>1)
        {
            return vec3(0);
        }
        //碰撞测试
        float depth = texture2D(depthtex0,positionInScreenCoord.st).x;//只要是从深度缓冲中查深度,都是屏幕坐标
        //如果成功命中或得到最大迭代次数--直接返回对应颜色
        if(depth<=positionInScreenCoord.z||i==iteration-1)
        {
            return texture2D(texture,positionInScreenCoord.st).rgb;
        }
    }
    return vec3(0);
}

/*
* @function drawWater : 基础水面绘制
* @param color : 原颜色
* @param positionInWorldCoord : 我的世界坐标
* @param positionInViewCoord : 眼坐标
* @param normal : 眼坐标系下的法线
* @return : 绘制水面后的颜色
* @explain : 因为我太猪B了才会想到在gbuffers_water着色器中绘制水面
导致后续很难继续编程 我爬
*/
vec3 drawWater(vec3 color,vec4 positionInWorldCoord,vec4 positionInViewCoord,vec3 normal)
{//波浪的高低已经在水面顶点着色器中绘制完了,这里只是绘制水面的纹理
    positionInWorldCoord.xyz+=cameraPosition;//得到真实世界坐标

    //波浪系数
    float wave = getWave(positionInWorldCoord);
    
    vec3 newNormal = normal;
    newNormal.z +=0.05*(((wave-0.4)/0.6)*2-1);
    newNormal.x +=0.05*(((wave-0.4)/0.6)*2-1);
    newNormal = normalize(newNormal);

    //计算反射光线方向
    vec3 reflectDirection = reflect(positionInViewCoord.xyz, newNormal);
    vec3 finalColor = drawSkyFakeReflect(vec4(reflectDirection, 0));
    finalColor*= wave;//水面上的一切画面都受到波浪的影响。
    finalColor *=2;

    // 屏幕空间反射
    vec3 reflectColor = rayTrace(positionInViewCoord.xyz, reflectDirection);
    if(length(reflectColor)>0)
    {
        float fadeFactor = 1- clamp(pow(abs(texcoord.x-0.5)*2,2),0,1);
        finalColor = mix(finalColor,reflectColor,fadeFactor);
    }
    
    //投射
    float cosine = dot(normalize(normal),normalize(positionInViewCoord.xyz));
    cosine = clamp(abs(cosine),0,1);
    float factor = pow(1.0-cosine,4); 
    finalColor = mix(color,finalColor,factor);
    //假反射 --太阳
    finalColor +=drawSkyFakeSun(vec4(reflectDirection,0))*0.45;//上面那个天空反射受到菲涅尔透射系数的影响,而太阳是不受影响的,因此最后加上

    return finalColor;
}
/*
* @function screenDepthToLinerDepth : 深度缓冲转线性深度
* @param screenDepth : 深度缓冲中的深度
* @return : 真实深度 -- 以格为单位
*/
float screenDepthToLinerDepth(float screenDepth)
{
    return 2 * near * far / ((far + near) - screenDepth * (far - near));
}
/*
* @function getUnderWaterFadeOut : 计算水下淡出系数
* @param d0 : 深度缓冲0中的原始数值
* @param d1 : 深度缓冲1中的原始数值
* @param positionInViewCoord : 眼坐标包不包含水面均可，因为我们将其当作视线方向向
量
* @param normal : 眼坐标系下的法线
* @return : 淡出系数
*/
float getUnderWaterFadeOut(float d0,float d1,vec4 positionInViewCoord,vec3 normal)
{
    //转线性深度
    d0 = screenDepthToLinerDepth(d0);
    d1 = screenDepthToLinerDepth(d1);

    //计算实现和法线夹角余弦值
    float cosine = dot(normalize(positionInViewCoord.xyz), normalize(normal));
    //cosine = clamp(abs(cosine), 0, 1);

    return clamp(1.0 - (d1 - d0) * 0.1, 0, 1);;//说白了就是求出水底到水面的深度,以此来得到一个插值
    
}
/*
* @function getCaustics : 获取焦散亮度缩放倍数
* @param positionInWorldCoord : 当前点在 “我的世界坐标系” 下的坐标
* @return : 焦散亮暗斑纹的亮度增益
*/
float getCaustics(vec4 positionInWorldCoord)
{
    positionInWorldCoord.xyz+=cameraPosition;

    //微波1
    float speed1 = float(worldTime)/(noiseTextureResolution*15);
    vec3 coord1 = positionInWorldCoord.xyz/noiseTextureResolution;
    coord1.x *=4;
    coord1.x+=speed1*2+coord1.z;
    coord1.z -=speed1;
    float noise1 = texture2D(noisetex,coord1.xz).x;
    noise1 = noise1*2-1.0;

    //微波2
    float speed2 = float(worldTime)/(noiseTextureResolution*15);
    vec3 coord2 = positionInWorldCoord.xyz/noiseTextureResolution;
    coord2.x *=4;
    coord2.z += speed2*2 + coord2.x;
    coord2.x -= speed2;
    float noise2 = texture2D(noisetex, coord2.xz).x;
    noise2 = noise2*2 - 1.0;
    return noise1 + noise2; // 叠加
}





/* DRAWBUFFERS: 01 */
void main() {
    //vec4 color = texture2D(shadow, texcoord.st);
    vec4 color = texture2D(texture, texcoord.st);
    
// 
//     float depth0 = texture2D(depthtex0, texcoord.st).x;
    
//     // 利用深度缓冲建立带深度的ndc坐标
//     vec4 positionInNdcCoord = vec4(texcoord.st*2-1, depth0*2-1, 1);

//     // 逆投影变换 -- ndc坐标转到裁剪坐标
//     vec4 positionInClipCoord = gbufferProjectionInverse * positionInNdcCoord;

//     // 透视除法 -- 裁剪坐标转到眼坐标
//     vec4 positionInViewCoord = vec4(positionInClipCoord.xyz/positionInClipCoord.w, 1.0);

//     // 逆 “视图模型” 变换 -- 眼坐标转 “我的世界坐标” 
//     vec4 positionInWorldCoord = gbufferModelViewInverse * positionInViewCoord;
    // 带水面方块的坐标转换
    float depth0 = texture2D(depthtex0, texcoord.st).x;
    vec4 positionInNdcCoord0 = vec4(texcoord.st*2-1, depth0*2-1, 1);
    vec4 positionInClipCoord0 = gbufferProjectionInverse * positionInNdcCoord0;
    vec4 positionInViewCoord0 = vec4(positionInClipCoord0.xyz/positionInClipCoord0.w,1.0);
    vec4 positionInWorldCoord0 = gbufferModelViewInverse * positionInViewCoord0;
    // 不带水面方块的坐标转换
    float depth1 = texture2D(depthtex1, texcoord.st).x;
    vec4 positionInNdcCoord1 = vec4(texcoord.st*2-1, depth1*2-1, 1);
    vec4 positionInClipCoord1 = gbufferProjectionInverse * positionInNdcCoord1;
    vec4 positionInViewCoord1 = vec4(positionInClipCoord1.xyz/positionInClipCoord1.w,1.0);
    vec4 positionInWorldCoord1 = gbufferModelViewInverse * positionInViewCoord1;
    
    float underWaterFadeOut = getUnderWaterFadeOut(depth0, depth1,positionInViewCoord0, normal); // 水下淡出系数

    // 计算泛光
    //color.rgb += getBloom();

    // 绘制阴影
    float id = texture2D(colortex2,texcoord.st).x;//知道了这个顶点的材质ID
    if(id!=10089&&id!=10090)//不是两种发光物,才绘制阴影
    {
        color = getShadow(color, positionInWorldCoord1,underWaterFadeOut);  
    }

     //color.rgb = pow(color.rgb,vec3(1/1.5));
     //color.rgb*=vec3(0.499,0.527,0.114);
    int hour = worldTime/1000;
    int next = (hour+1<24)?(hour+1):(0);//形成了一个循环
    float delta = float(worldTime-hour*1000)/1000;


    color.xyz = drawSky(color.xyz,positionInViewCoord0,positionInWorldCoord0);//天空有个云层也是按照有水版本的变换绘制的,否则无法渲染云层
    vec4 temp = texture2D(colortex4,texcoord.st);
    vec3 normal = temp.xyz*2-1;
    float isWater = temp.w;
    float caustics = getCaustics(positionInWorldCoord1);

    if(isWater==1||isEyeInWater==1)
    {
        color.rgb *= 1.0+caustics*0.25*underWaterFadeOut;
    }
    
    if(isWater==1)
    {
        color.rgb = drawWater(color.rgb,positionInWorldCoord0,positionInViewCoord0,normal);
    }
    
    gl_FragData[0] = color;
    gl_FragData[1] = getBloomSource(color);
}