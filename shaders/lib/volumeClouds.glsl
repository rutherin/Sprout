////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////ORIGINAL SHADER SPROUT BY SILVIA//////////////////////////////////
/////Anyone downloading this has permission to edit anything within for personal use, but //////////
/////////////////////redistribution of any kind requires explicit permission.///////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////

//Volumetric Clouds Originally by RRe36 (https://github.com/rre36)
#define vc_steps 18     //[10 12 14 16 18 20 22 24 26 28 30]
#define vc_altitude 512.0   //[384.0 512.0 768.0 1024.0]
#define vc_thickness 284.0  //[128.0 192.0 224.0 256.0 288.0 320.0 384.0 448.0 512.0]
#define vc_breakThreshold 0.05 //[0.2 0.1 0.05 0.025 0.01]
#define VCloud_Quality 0.8 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.5 3.0]
#define VClouds
#define VC_Octaves 2 //[1 2 3 4]
#define VC_Density 1.0 //[0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.5 3.0]
#define VC_Poof 1.2 //[0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.5 3.0]
#define VC_Scattering_Steps 7 //[4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 25 30]

#define RRe36 0 //https://github.com/rre36

const float vc_highedge     = vc_altitude+vc_thickness;
uniform float sunAngle;
uniform float eyeAltitude;
uniform sampler3D colortex7;

float vc_windTick   = frameTimeCounter*0.02;
const float invLog2 = 1.0/log(2.0);

vec3 planetCurvePosition(in vec3 x) {
    return vec3(x.x, length(x + vec3(0.0, atmosphere_planetRadius, 0.0))-atmosphere_planetRadius, x.z);
}

float getNoise3D(vec3 pos) {
    vec3 i          = floor(pos);
    vec3 f          = fract(pos);

    vec2 p1         = (i.xy+i.z*vec2(17.0)+f.xy);
    vec2 p2         = (i.xy+(i.z+1.0)*vec2(17.0))+f.xy;
    vec2 c1         = (p1+0.5)/noiseTextureResolution;
    vec2 c2         = (p2+0.5)/noiseTextureResolution;
    float r1        = texture(noisetex, c1).r;
    float r2        = texture(noisetex, c2).r;
    return mix(r1, r2, f.z);
}

float getSlicedWorley(in vec3 pos) {
    pos /= 54.0;

    return texture(colortex7, fract(pos)).y;
}

float scatterIntegral(float transmittance, const float coeff) {
    float a   = -1.0/coeff;
    return transmittance * a - a;
}

float fbm(vec3 pos, vec3 offset, const float persistence, const float scale, const int octaves) {
    float n     = 1.0;
    float a     = 0.5;
    vec3 shift  = offset;
    float d     = a;

    for (int i = 0; i<(1 + VC_Octaves); ++i) {
        n   += getNoise3D(pos + shift*(1.0+(float(i)/(1 + VC_Octaves))*0.25))*a;
        pos *= scale;
        a   *= persistence;
        d   += a;
    }
    return n/d;
}

float vc_getCoverage(vec3 pos) {
    const float lowEdge     = vc_altitude;
    const float highEdge    = vc_altitude+vc_thickness;

    float lowErode  = 1.0-smoothstep(lowEdge, lowEdge+vc_thickness*0.15, pos.y);
    float highErode = smoothstep(lowEdge+vc_thickness*0.005, highEdge, pos.y);

    float lowFade   = smoothstep(lowEdge, lowEdge+vc_thickness*0.08, pos.y);
    float highFade  = 1.0-smoothstep(highEdge-vc_thickness*0.15, highEdge, pos.y);

    pos *= 0.003;

    vec3 wind       = vec3(vc_windTick, 0.0, 0.0);

    float lcoverage = GetNoise(pos.xz*0.1+wind.xz*0.1);
        lcoverage   = smoothstep(0.2, 1.9, lcoverage);

    float shape     = fbm(pos, wind, 0.45, 2.3, 3);
        shape      -= 1.47;
        shape      *= lowFade;
        shape      *= highFade;
        shape      -= lowErode*0.15*(1.0-lowFade*0.69);
        shape      -= highErode*0.2;

        shape      -= lcoverage*0.25;

    return max(shape, 0.0);
}
float vc_getShape(vec3 pos, float coverage) {
    pos *= 0.12;

    vec3 wind       = vec3(vc_windTick, 0.0, 0.0);

    float shape     = coverage;

    float div   = 0.0;
    float noise = getSlicedWorley(pos*1.0+wind)  * VC_Poof;    div += 1.0;
          noise += getSlicedWorley(pos*1.0+wind) * VC_Poof;    div += 2.0;
          noise += getSlicedWorley(pos*1.0+wind) * VC_Poof;    div += 1.0;
          noise += getSlicedWorley(pos*1.0+wind) * VC_Poof;    div += 0.2;
          noise += getSlicedWorley(pos*1.0+wind) * VC_Poof;    div += 1.1;
        //pos += shape*2.0;
        //noise  += getSlicedWorley(pos*113.0+wind*0.1)*0.25; div += 0.05;  //idk, didn't feel necessary

        noise /= div;

        shape -= (1.0-noise)*0.16;

    return max(shape*0.9 * VC_Density, 0.0);
}

float vc_mie(float x, float g) {
    float temp  = 1.0 + pow2(g) - 2.0*g*x;
    return (1.0 - pow2(g)) / ((19.0*PI) * temp*(temp*0.5+0.5));
}

float vc_miePhase(float x, float gmult) {
    float mie1  = vc_mie(x, 0.8*gmult);
    float mie2  = vc_mie(x, -0.5*gmult);
    return mix(mie1, mie2, 0.88);
}

float vc_getLD(vec3 rpos, const int steps, vec3 lvec) {
    const float density     = VC_Density;

    vec3 dir    = normalize(mat3(gbufferModelViewInverse)*lvec);
    float stepSize = (24.5/steps);
    vec3 rstep  = dir;

    float ld    = 0.0;

    for (int i = 0; i<steps; i++, rpos += dir*stepSize) {
        if (rpos.y<vc_altitude || rpos.y>vc_highedge) continue;
        float coverage = vc_getCoverage(rpos);
        if (coverage <= 0.0) continue;

        float oD    = vc_getShape(rpos, coverage)*stepSize;
        if (oD <= 0.0) continue;

        ld += oD;
        stepSize *= 2.3;
    }
    return ld * density;
}
float vc_getScatter(float ld, float powder, float vdotl, float ldscale, float phaseg) {
    float transmittance     = exp2(-ld*ldscale);
    float phase             = vc_miePhase(vdotl, phaseg)*0.95+0.05;

    return max(powder*phase*transmittance*invLog2, 0.0);
}

void vc_multiscatter(inout vec2 scatter, float oD, vec3 rpos, vec3 lvec, float vdotl, float t, float stept, float pmie) {
    float ld    = vc_getLD(rpos, VC_Scattering_Steps, lvec);
    float integral = scatterIntegral(stept, 1.0);
    float powder = exp(-oD -ld);
        powder  = mix(1.0-powder, 1.0+powder*0.25, pmie);
    
    float s     = 0.0;
    float n     = 0.0;

    float scattercoeff = 1.0;

    for (int i = 0; i<3; i++) {
        float scoeff    = pow(0.5, float(i));
        float ldcoeff   = pow(0.15, float(i));
        float phasecoeff = pow(0.85, float(i));

        scattercoeff *= scoeff;

        s += vc_getScatter(ld, powder, vdotl, ldcoeff, phasecoeff)*scattercoeff;
        n += scoeff;
    }
    float skylight  = sqrt(clamp01((rpos.y-vc_altitude)/vc_thickness));

    s *= 1.0/n;

    scatter.x += s*integral*t;
    scatter.y += skylight*integral*t;
}

void vc_render(inout vec3 scenecolor, vec3 viewvec, vec3 upvec, vec3 lightvec, vec3 camerapos, float vdotl, float dither, vec3 worldpos) {
    vec3 wvec   = mat3(gbufferModelViewInverse)*viewvec;
    vec2 psphere = rsi((atmosphere_planetRadius+eyeAltitude)*upvec, viewvec, atmosphere_planetRadius);
    bool visible = !((eyeAltitude<vc_altitude && psphere.y>0.0) || (eyeAltitude>(vc_altitude+vc_thickness) && wvec.y>0.0));

    if (visible) {
        const float lowEdge     = vc_altitude;
        const float highEdge    = vc_altitude+vc_thickness;

        vec2 bsphere    = rsi(vec3(0.0, 1.0, 0.0)*atmosphere_planetRadius+eyeAltitude, wvec, atmosphere_planetRadius+lowEdge);
        vec2 tsphere    = rsi(vec3(0.0, 1.0, 0.0)*atmosphere_planetRadius+eyeAltitude, wvec, atmosphere_planetRadius+highEdge);

        float startdist = eyeAltitude>highEdge ? tsphere.x : bsphere.y;
        float enddist   = eyeAltitude>highEdge ? bsphere.x : tsphere.y;

        vec3 startpos   = wvec*startdist;
        vec3 endpos     = wvec*enddist;

        float mrange    = (1.0-clamp01((eyeAltitude-highEdge)*0.2)) * (1.0-clamp01((lowEdge-eyeAltitude)*0.2));

        startpos        = mix(startpos, gbufferModelViewInverse[3].xyz, mrange);
        endpos          = mix(endpos, worldpos*(highEdge*20.0/far), mrange);

        startpos    = planetCurvePosition(startpos);
        endpos      = planetCurvePosition(endpos);

        vec3 bstep      = (endpos-startpos)/vc_steps;
        const float blength = vc_thickness/vc_steps;
        float stepsCoeff = length(bstep)/blength;
            stepsCoeff  = 0.5+clamp(stepsCoeff-1.25, 0.0, 3.0)*0.4 * VCloud_Quality;
            stepsCoeff  = mix(stepsCoeff, 30.0, pow3(mrange));      //this compensates the sample loss when being inside the cloud volume
        int steps       = int(vc_steps*stepsCoeff);

        vec3 rstep  = (endpos-startpos)/steps;
        vec3 rpos   = rstep*dither+startpos+camerapos;

        float rlength = length(rstep);

        vec2 scatter    = vec2(0.0);
        float transmittance = 1.0;
        float fade      = 1.0;

        vec3 sunlight   = lightColor;
            sunlight    = vec3(1.0, 0.95, 0.9) * 2.0 * ((SunColor * 4.8) + (MoonColor * 2));
        vec3 skylight   = ambientColor * 3.0 * ((SunColor * 1.2) + (MoonColor * 0.3));
        //if (sunAngle > 0.0 && sunAngle < 0.05) skylight = vec3(0.7, 1.1, 1.3) * 0.5;
        //if (sunAngle > 0.95 && sunAngle < 1.00) skylight = vec3(0.7, 1.1, 1.3) * 0.5;


        float oDmult    = sqrt(steps/(rlength*1.73205080757) * 0.4);
        float powderMie = clamp01(vc_mie(vdotl, 0.25))/0.25;

        for (int i = 0; i<steps; ++i, rpos += rstep) {
            if (rpos.y<lowEdge || rpos.y>highEdge || transmittance<vc_breakThreshold) {
                if (mrange<0.5) continue;
                else break;
            }
            float dist  = length(rpos-camerapos);
            float dfade = clamp01((dist-3000.0)/27000);
            if ((1.0-dfade)<0.01) continue;

            float coverage = vc_getCoverage(rpos);
            if (coverage <= 0.0) continue;

            float oD    = vc_getShape(rpos, coverage)*rlength;
            if (oD <= 0.0) continue;

            float stept = exp2(-oD*invLog2);

            fade   -= dfade*transmittance;

            vc_multiscatter(scatter, oD*oDmult, rpos, lightvec, vdotl, transmittance, stept, powderMie);

            transmittance *= stept;
        }
        transmittance   = clamp((transmittance-vc_breakThreshold)/(1.0-vc_breakThreshold), 0.0, 1.0);
        fade            = clamp01(pow2(fade));

        vec3 color      = sunlight*scatter.x*PI + skylight*scatter.y*0.5;
            color      *= 0.57;

        transmittance   = mix(1.0, transmittance, fade);

        scenecolor     *= transmittance;
        scenecolor     += color*fade;
    }
}