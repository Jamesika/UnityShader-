// Upgrade NOTE: replaced '_LightMatrix0' with 'unity_WorldToLight'

Shader "Hidden/ForwardRendering"
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
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 viewDir : TEXCOORD3;
				float3 normal : TEXCOORD4;
			};

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv.xy = TRANSFORM_TEX(v.uv,_MainTex);

				o.viewDir = WorldSpaceViewDir(v.vertex).xyz;
				o.normal = mul(UNITY_MATRIX_M, v.normal);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float3 normal = normalize(i.normal);
				float3 lightDir = normalize(_WorldSpaceLightPos0);
				float3 viewDir = normalize(i.viewDir);

				// 光照衰减
				float atten = 1.0;

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
			#pragma multi_compile_fwdadd
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
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 viewDir : TEXCOORD3;
				float3 normal : TEXCOORD4;
				float3 worldPos : TEXCOORD5;
			};

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv.xy = TRANSFORM_TEX(v.uv,_MainTex);

				o.viewDir = WorldSpaceViewDir(v.vertex).xyz;
				o.normal = mul(UNITY_MATRIX_M, v.normal);
				o.worldPos = mul(UNITY_MATRIX_M, v.vertex);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float3 normal = normalize(i.normal);

				#ifdef USING_DIRECTIONAL_LIGHT
					float3 lightDir = normalize(_WorldSpaceLightPos0);
				#else
					float3 lightDir = normalize(_WorldSpaceLightPos0- i.worldPos);
				#endif

				//float3 lightDir = normalize(i.lightDir);
				float3 viewDir = normalize(i.viewDir);

				// 光照衰减, 使用纹理作为查找表设置衰减值
				#ifdef USING_DIRECTIONAL_LIGHT
					float atten = 1.0;
				#else
					float3 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1));
					float atten = tex2D(_LightTexture0, dot( lightCoord , lightCoord ).rr ).UNITY_ATTEN_CHANNEL;
				#endif

				float3 albedo = tex2D(_MainTex, i.uv)*_Color.rgb;
				 
				// 漫反射
				fixed3 diffuse = _LightColor0.rgb*albedo*max(0, dot(normal, lightDir));
				// 高光
				float3 halfViewLight = normalize(viewDir + lightDir);
				fixed3 specular = _LightColor0.rgb*_Specular*pow(max(0, dot(halfViewLight, normal)),_Gloss);
				return fixed4((diffuse + specular)*atten,1);
			}
			ENDCG
		}
	 
	}
	Fallback "Specular"
}
