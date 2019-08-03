#version 460 compatibility

uniform mat4 gbufferModelView;
varying vec2 texcoord;

void main(){
	gl_Position = ftransform();

}