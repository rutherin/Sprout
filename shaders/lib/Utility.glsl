////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////ORIGINAL SHADER SPROUT BY SILVIA//////////////////////////////////
/////Anyone downloading this has permission to edit anything within for personal use, but //////////
/////////////////////redistribution of any kind requires explicit permission.///////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////

#define fsqrt(x) intBitsToFloat(0x1FBD1DF5 + (floatBitsToInt(x) >> 1)) // Error of 1.42%

float flength(vec2 x) {
	return fsqrt(dot(x, x));
}

float flength(vec3 x) {
	return fsqrt(dot(x, x));
}

float flength(vec4 x) {
	return fsqrt(dot(x, x));
}

#define max3(x,y,z)       max(x,max(y,z))
#define min3(a,b,c)       min(min(a,b),c)

#define clamp01(x) clamp(x, 0.0, 1.0)

#define max0(x) max(x, 0.0)

#define LOG2 log(2.0) 
#define rLOG2 1/LOG2

#define pow2(x) (x * x)
#define pow3(x) pow2(x) * x
#define pow4(x) pow2(pow2(x))
#define pow5(x) pow2(pow2(x)) * x

vec4 powf(vec4 a, float b) { return pow(a, vec4(b)); }
vec3 powf(vec3 a, float b) { return pow(a, vec3(b)); }
vec2 powf(vec2 a, float b) { return pow(a, vec2(b)); }

#define diagonal2(mat) vec2((mat)[0].x, (mat)[1].y)
#define diagonal3(mat) vec3((mat)[0].x, (mat)[1].y, mat[2].z)

#define transMAD(mat, v) (     mat3(mat) * (v) + (mat)[3].xyz)
#define  projMAD(mat, v) (diagonal3(mat) * (v) + (mat)[3].xyz)

#define lumaCoeff vec3(0.2125, 0.7254, 0.0721)

#define toLinear(x) powf(x, 2.2)
#define toSRGB(x) powf(x, 1.0 / 2.2)

mat2 rotate(float rad) {
	return mat2(
	vec2(cos(rad), -sin(rad)),
	vec2(sin(rad), cos(rad))
	);
}

#define HASHSCALE1 .1031
#define HASHSCALE3 vec3(.1031, .1030, .0973)
#define HASHSCALE4 vec4(1031, .1030, .0973, .1099)

float hash11(float p) {
	vec3 p3  = fract(vec3(p) * HASHSCALE1);
  p3 += dot(p3, p3.yzx + 19.19);
  return fract((p3.x + p3.y) * p3.z);
}

float hash12(vec2 p) {
	vec3 p3  = fract(vec3(p.xyx) * HASHSCALE1);
  p3 += dot(p3, p3.yzx + 19.19);
  return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p3) {
	p3  = fract(p3 * HASHSCALE1);
  p3 += dot(p3, p3.yzx + 19.19);
  return fract((p3.x + p3.y) * p3.z);
}

vec2 hash23(vec3 p3) {
	p3 = fract(p3 * HASHSCALE3);
  p3 += dot(p3, p3.yzx + 19.19);
  return fract((p3.xx + p3.yz) * p3.zy);
}

#define g(a) (4-(a).x-((a).y<<1))%4

float bayer(vec2 tc){
  ivec2 p = ivec2(tc);
  return float(
     g(p>>3&1)    +
    (g(p>>2&1)<<2)+
    (g(p>>1&1)<<4)+
    (g(p   &1)<<6)
  )/255.;
}

float bayer2(vec2 a){
    a = floor(a);
    return fract( dot(a, vec2(.5, a.y * .75)) );
}

#define bayer4(a)   (bayer2( .5*(a))*.25+bayer2(a))
#define bayer8(a)   (bayer4( .5*(a))*.25+bayer2(a))
#define bayer16(a)  (bayer8( .5*(a))*.25+bayer2(a))
#define bayer32(a)  (bayer16(.5*(a))*.25+bayer2(a))
#define bayer64(a)  (bayer32(.5*(a))*.25+bayer2(a))
#define bayer128(a) (bayer64(.5*(a))*.25+bayer2(a))
#define bayer256(a) (bayer128(.5*(a))*.25+bayer2(a))

#define circlemap(p) (vec2(cos((p).y*TAU), sin((p).y*TAU)) * fsqrt(p.x))
#define semicirclemap(p) (vec2(cos((p).y*PI), sin((p).y*PI)) * fsqrt(p.x) )

#define hammersley(i, N) vec2( float(i) / float(N), float( bitfieldReverse(i) ) * 2.3283064365386963e-10 )

vec2 lattice(int i, int N){
	float sn = fsqrt(float(N));
	return vec2(mod( float(i) * PI, sn ) / sn, float(i) / float(N));
}

int bayer64x64(ivec2 p){
    return
         g(p>>5&1)    +
        (g(p>>4&1)<<2)+
        (g(p>>3&1)<<4)+
        (g(p>>2&1)<<6)+
        (g(p>>1&1)<<8)+
        (g(p   &1)<<10)
    ;
}
