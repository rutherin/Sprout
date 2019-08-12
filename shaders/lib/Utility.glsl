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

#define diagonal2(mat) vec2((mat)[0].x, (mat)[1].y)
#define diagonal3(mat) vec3((mat)[0].x, (mat)[1].y, mat[2].z)

#define transMAD(mat, v) (     mat3(mat) * (v) + (mat)[3].xyz)
#define  projMAD(mat, v) (diagonal3(mat) * (v) + (mat)[3].xyz)

#define lumaCoeff vec3(0.2125, 0.7254, 0.0721)
