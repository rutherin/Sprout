#define vc_steps 20
#define vc_altitude 512.0
#define vc_thickness 384.0
#define vc_breakThreshold 0.05

const float vc_highedge     = vc_altitude+vc_thickness;

uniform float eyeAltitude;
uniform sampler3D colortex7;

float vc_windTick   = frameTimeCounter*0.1;
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
    pos /= 64.0;

    return texture(colortex7, fract(pos)).x;
}
float getSlicedWorley3x(in vec3 pos) {
    pos /= 64.0;
    
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

    for (int i = 0; i<octaves; ++i) {
        n   += getNoise3D(pos + shift*(1.0+(float(i)/octaves)*0.25))*a;
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
    float highErode = smoothstep(lowEdge+vc_thickness*0.2, highEdge, pos.y);

    float lowFade   = smoothstep(lowEdge, lowEdge+vc_thickness*0.08, pos.y);
    float highFade  = 1.0-smoothstep(highEdge-vc_thickness*0.15, highEdge, pos.y);

    pos *= 0.003;

    vec3 wind       = vec3(vc_windTick, 0.0, 0.0);

    float lcoverage = GetNoise(pos.xz*0.1+wind.xz*0.1);
        lcoverage   = smoothstep(0.2, 0.9, lcoverage);

    float shape     = fbm(pos, wind, 0.5, 2.3, 3);
        shape      -= 1.45;
        shape      *= lowFade;
        shape      *= highFade;
        shape      -= lowErode*0.15*(1.0-lowFade*0.9);
        shape      -= highErode*0.2;

        shape      -= lcoverage*0.25;

    return max(shape, 0.0);
}
float vc_getShape(vec3 pos, float coverage) {
    pos *= 0.12;

    vec3 wind       = vec3(vc_windTick, 0.0, 0.0);

    float shape     = coverage;

    float div   = 0.0;
    float noise = getSlicedWorley3x(pos*1.0+wind*0.1);    div += 1.0;
        //pos += shape*2.0;
        //noise  += getSlicedWorley3x(pos*3.0+wind*0.1)*0.25; div += 0.25;  //idk, didn't feel necessary

        noise /= div;

        shape -= (1.0-noise)*0.12;

    return max(shape, 0.0);
}

float vc_mie(float x, float g) {
    float temp  = 1.0 + pow2(g) - 2.0*g*x;
    return (1.0 - pow2(g)) / ((4.0*PI) * temp*(temp*0.5+0.5));
}

float vc_miePhase(float x, float gmult) {
    float mie1  = vc_mie(x, 0.8*gmult);
    float mie2  = vc_mie(x, -0.5*gmult);
    return mix(mie1, mie2, 0.38);
}

float vc_getLD(vec3 rpos, const int steps, vec3 lvec) {
    const float density     = 1.0;

    vec3 dir    = normalize(mat3(gbufferModelViewInverse)*lvec);
    float stepSize = (33.3/steps);
    vec3 rstep  = dir;

    float ld    = 0.0;

    for (int i = 0; i<steps; i++, rpos += dir*stepSize) {
        if (rpos.y<vc_altitude || rpos.y>vc_highedge) continue;
        float coverage = vc_getCoverage(rpos);
        if (coverage <= 0.0) continue;

        float oD    = vc_getShape(rpos, coverage)*stepSize;
        if (oD <= 0.0) continue;

        ld += oD;
        stepSize *= 2.2;
    }
    return ld * density;
}
float vc_getScatter(float ld, float powder, float vdotl, float ldscale, float phaseg) {
    float transmittance     = exp2(-ld*ldscale);
    float phase             = vc_miePhase(vdotl, phaseg)*0.95+0.05;

    return max(powder*phase*transmittance*invLog2, 0.0);
}

void vc_multiscatter(inout vec2 scatter, float oD, vec3 rpos, vec3 lvec, float vdotl, float t, float stept, float pmie) {
    float ld    = vc_getLD(rpos, 6, lvec);
    float integral = scatterIntegral(stept, 1.0);
    float powder = exp(-oD -ld);
        powder  = mix(1.0-powder, 1.0+powder*0.5, pmie);
    
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

void vc_render(inout vec3 scenecolor, vec3 viewvec, vec3 upvec, vec3 lightvec, vec3 camerapos, float vdotl, float dither) {
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

        startpos    = planetCurvePosition(startpos);
        endpos      = planetCurvePosition(endpos);

        vec3 bstep      = (endpos-startpos)/vc_steps;
        const float blength = vc_thickness/vc_steps;
        float stepsCoeff = length(bstep)/blength;
            stepsCoeff  = 0.5+clamp(stepsCoeff-1.25, 0.0, 3.0)*0.4;
        int steps       = int(vc_steps*stepsCoeff);

        vec3 rstep  = (endpos-startpos)/steps;
        vec3 rpos   = rstep*dither+startpos+camerapos;

        float rlength = length(rstep);

        vec2 scatter    = vec2(0.0);
        float transmittance = 1.0;
        float fade      = 1.0;

        vec3 sunlight   = lightColor;
            sunlight    = vec3(0.4, 0.5, 0.6) * 3.0 * (SunColor + (MoonColor * 10));
        vec3 skylight   = ambientColor;

        float oDmult    = sqrt(steps/(rlength*1.73205080757));
        float powderMie = clamp01(vc_mie(vdotl, 0.25))/0.25;

        for (int i = 0; i<steps; ++i, rpos += rstep) {
            if (rpos.y<lowEdge || rpos.y>highEdge || transmittance<vc_breakThreshold) continue;
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
        fade            = clamp01(fade);

        vec3 color      = sunlight*scatter.x*PI + skylight*scatter.y/PI;
            color      *= 0.7;

        transmittance   = mix(1.0, transmittance, fade);

        scenecolor     *= transmittance;
        scenecolor     += color*fade;
    }
}