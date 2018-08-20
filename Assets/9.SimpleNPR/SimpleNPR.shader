Shader "Hidden/SimpleNPR"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Color("Color Tint", Color) = (1,1,1,1)

		_RampTex("RampTex", 2D) = "white"{}
		_Outline("Outline width",Float) = 0.1
		_OutlineColor("Outline color",Color) = (1,1,1,1)
		_Specular("Specular Color", Color) = (1,1,1,1)
		_SpecularScale("Specular Scale", Range(0,0.2)) = 0.01

		_Position("Pos",Vector) = (0,0,0,0)
		_Rotation("Rot",Range(-10,10)) = 0
		_DScale("Directional Scaling",Range(-10,10)) = 0
		_SplitX("Split X",Range(0,1)) = 0
		_SplitY("Split Y",Range(0,1)) = 0
		_SquarN("Square_Origin N", Float) = 0
		_SquarS("Square_Origin S", Range(0,1)) = 0

		_Square("Square_Modified", Range(0,1)) = 0.2
	}
	SubShader
	{
		ZWrite On ZTest On

		// 先渲染背面, 获得轮廓线
		Pass
		{
			NAME "OUTLINE"

			Cull front

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
			};

			float _Outline;
			fixed4 _OutlineColor;

			v2f vert(appdata v)
			{
				v2f o;
				// 为了描边, 需要变换到视角空间下
				float4 pos = mul(UNITY_MATRIX_MV, v.vertex);
				float3 normal = mul(UNITY_MATRIX_IT_MV, v.normal);
				// 为了防止背面遮挡正面...
				normal.z = -0.5;
				normal = normalize(normal);
				// 向外偏移
				pos = pos + float4(normal, 0)*_Outline;
				o.pos = mul(UNITY_MATRIX_P, pos);

				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				 return fixed4(_OutlineColor.rgb, 1);
			}
			ENDCG
		}
		
		// 再正常渲染一波正面
		Pass
		{
			Tags{ "LightMode" = "ForwardBase" }
			Cull back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"


			sampler2D _MainTex;
			fixed4 _Color;
			sampler2D _RampTex;
			float _Outline;
			fixed4 _OutlineColor;
			fixed4 _Specular;
			fixed _SpecularScale;

			float4 _MainTex_ST;
			float4 _RampTex_ST;

			// 风格化高光
			float4 _Position;
			float _Rotation;
			float _DScale;
			float _SplitX;
			float _SplitY;
			float _SquarN;
			float _SquarS;
			float _Square;

			struct appdata
			{
				float4 vertex : POSITION;
				float2 texcoord : TEXCOORD0;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float3 worldPos : TEXCOORD0;
				float3 worldNormal : TEXCOORD1;
				float3 worldTangent : TEXCOORD2;
				float3 worldBinormal : TEXCOORD3;
				float2 uv : TEXCOORD4;
				SHADOW_COORDS(5)
			};

			v2f vert(appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

				 
				o.worldPos = mul(UNITY_MATRIX_M, v.vertex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				o.worldTangent = UnityObjectToWorldDir(v.tangent);
				o.worldBinormal = cross(o.worldNormal, o.worldTangent)*v.tangent.w;

				TRANSFER_SHADOW(o);

				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				fixed4 red = fixed4(1,0,0,1);

				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldTangent = normalize(i.worldTangent);
				fixed3 worldBinormal = normalize(i.worldBinormal);
				fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));

				// 这是风格化高光的关键向量!===================
				fixed3 worldHalfDir = normalize(worldLightDir + worldViewDir);
				float3 H = worldHalfDir;
				float3 dv = worldBinormal;
				float3 du = worldTangent;
				
				// 平移
				H = normalize(H + _Position.x*du + _Position.y*dv);
				// 旋转 (按照原文这里是一个2D旋转, 是让 du,dv 在平面内旋转)
				float rad = _Rotation;
				float3 n = worldNormal;
				float cosR = cos(rad);
				float sinR = sin(rad);
				float3x3 rot = float3x3
					(n.x*n.x*(1-cosR)+cosR, n.x*n.y*(1-cosR)+n.z*sinR, n.x*n.z*(1-cosR)-n.y*sinR,
					n.x*n.y*(1-cosR)-n.z*sinR, n.y*n.y*(1-cosR)+cosR, n.y*n.z*(1-cosR)+n.x*sinR,
					n.x*n.z*(1-cosR)+n.y*sinR, n.y*n.z*(1-cosR)-n.x*sinR, n.z*n.z*(1-cosR)+cosR);
				//H = normalize(mul(rot, H));
				du = normalize(mul(rot, du));
				dv = normalize(mul(rot, dv));
				// 拉伸
				float delta = _DScale;
				H = normalize(H - delta * dot(H, du)*du);
				// 分裂
				float dotV = dot(H, dv);
				float dotU = dot(H, du);
				float sgnV = 1;
				float sgnU = 1;
				if (dotV < 0)
					sgnV = -1;
				if (dotU < 0)
					sgnU = -1;
				H = normalize(H - _SplitX * sgnU*du - _SplitY * sgnV*dv);
				// 方块化1
				dotV = dot(H, dv);
				dotU = dot(H, du);
				float thetaV = acos(dotV);
				float thetaU = acos(dotU);
				float sqrnormU = sin(pow(2 * thetaU, _SquarN));
				float sqrnormV = sin(pow(2 * thetaV, _SquarN));
				H = normalize(H - _SquarS *(sqrnormU*dotU*du + sqrnormV*dotV * dv));

				// 方块化2
				dotV = dot(H, dv);
				dotU = dot(H, du);
				float3 dir = normalize(dotV * dv + dotU * du);
				float scale = pow(1-abs(abs(dot(dir, du)) - abs(dot(dir, dv))), 2);

				H = normalize(H + scale*_Square*worldNormal*0.38);

				worldHalfDir = H;
				// 风格化高光结束==============================

				fixed3 albedo = _Color.rgb*tex2D(_MainTex, i.uv);

				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz*albedo;

				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);// 光照衰减
				float diff = dot(worldNormal, worldLightDir);
				diff = (diff*0.5 + 0.5)*atten;// half lambert 
				fixed3 diffuse = _LightColor0 * tex2D(_RampTex, fixed2(diff, diff))*albedo;

				float spec = dot(worldNormal, worldHalfDir);
				float w = fwidth(spec)*2.0;// spec 导数, 抗锯齿
				//fixed3 specular = _LightColor0.rgb*_Specular*pow(max(0, dot(halfViewLight, worldNormal)), _Gloss);
				fixed3 specular = _LightColor0.rgb*_Specular*lerp(0, 1, smoothstep(-w, w, spec + _SpecularScale - 1))*step(0.0001, _SpecularScale);


				return fixed4(ambient + diffuse + specular, 1);
			}
			ENDCG
		}
	}
	//Fallback "Diffuse"
}
