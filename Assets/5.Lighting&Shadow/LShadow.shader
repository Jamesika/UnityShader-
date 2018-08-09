Shader "Hidden/LShadow"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_Color("Color Tint",Color) = (1,1,1,1)
		_Specular("Specular", Color) = (1,1,1,1)
		_Gloss("Gloss", Float) = 8
	}
	SubShader
	{
		ZWrite On
		ZTest On

		// Base Pass : 计算环境光， 自发光（只用计算一次的光）
		Pass
		{
			Tags { "LightMode" = "ForwardBase" }
			CGPROGRAM
			#pragma multi_compile_fwdbase
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color;
			fixed4 _Specular;
			float _Gloss;

			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				SHADOW_COORDS(3)
			};

			v2f vert(appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = TRANSFORM_TEX(v.uv,_MainTex);

				o.worldPos = mul(UNITY_MATRIX_M, v.vertex);
				o.normal = mul(UNITY_MATRIX_M, v.normal);
				TRANSFER_SHADOW(o);// 计算阴影纹理坐标
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float3 normal = normalize(i.normal);
				float3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				float3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));

				// 光照衰减 & 阴影
				//float atten = 1.0;
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

				float3 albedo = tex2D(_MainTex, i.uv)*_Color.rgb;
				// 环境光
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz*albedo;
				// 漫反射
				fixed3 diffuse = _LightColor0.rgb*albedo*max(0, dot(normal, lightDir));
				// 高光
				float3 halfViewLight = normalize(viewDir + lightDir);
				fixed3 specular = _LightColor0.rgb*_Specular*pow(max(0, dot(halfViewLight, normal)),_Gloss);
				 
				return fixed4(ambient + (diffuse + specular)*atten,1);
			}
			ENDCG
		}
		
		// Additional Pass : 计算每一个光源的影响
		Pass
		{
			Tags{ "LightMode" = "ForwardAdd" }
			Blend One One

			CGPROGRAM
			#pragma multi_compile_fwdadd_fullshadows
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color;
			fixed4 _Specular;
			float _Gloss;

			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				SHADOW_COORDS(3)
			};

			v2f vert(appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);

				o.worldPos = mul(UNITY_MATRIX_M, v.vertex);
				o.normal = mul(UNITY_MATRIX_M, v.normal);
				TRANSFER_SHADOW(o);// 计算阴影纹理坐标
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float3 normal = normalize(i.normal);
				float3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				float3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));

				// 光照衰减 & 阴影
				//float atten = 1.0;
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

				float3 albedo = tex2D(_MainTex, i.uv)*_Color.rgb;
				// 环境光
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz*albedo;
				// 漫反射
				fixed3 diffuse = _LightColor0.rgb*albedo*max(0, dot(normal, lightDir));
				// 高光
				float3 halfViewLight = normalize(viewDir + lightDir);
				fixed3 specular = _LightColor0.rgb*_Specular*pow(max(0, dot(halfViewLight, normal)),_Gloss);

				return fixed4(ambient + (diffuse + specular)*atten,1);
			}
			ENDCG
		}
	}
	Fallback "Specular"// Fallback 中存在包含 LightMode = ShadowCaster 的Pass
}
