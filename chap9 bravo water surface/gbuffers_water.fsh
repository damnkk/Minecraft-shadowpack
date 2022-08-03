#version 120

uniform sampler2D  texture;
uniform sampler2D lightmap;

uniform vec3 cameraPosition;
uniform int worldTime;
varying float id;
varying vec3 normal;
varying vec4 texcoord;
varying vec4 color;
varying vec4 lightMapCoord;


/*DRAWBUFFERS: 04*/
void main()
{ 
    vec4 light = texture2D(lightmap,lightMapCoord.st);
    gl_FragData[0] = vec4(vec3(0.05,0.2,0.3),0.5)*light;
    gl_FragData[1] = vec4(normal*0.5+0.5,1);
}