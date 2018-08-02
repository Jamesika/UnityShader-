Shader "Hidden/chapter7/Normal_TangentSpace"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Color("Color Tint",Color) = (1,1,1,1)
		_BumpMap("Normal Map", 2D) = "bump"{}
		_BumpScale("BumpScale", Float) = 1.0
		_Specular("Specular", Color) = (1,1,1,1)
		_Gloss("Gloss", Float) = 8
	}
	SubShader
	{
		Cull Off ZWrite on ztest on

		Pass
		{
			Tags { "LightMode" = "ForwardBase" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "Lighting.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color;
			sampler2D _BumpMap;
			float4 _BumpMap_ST;
			float _BumpScale;
			fixed4 _Specular;
			float _Gloss;


		struct appdata
		{
			float4 vertex : POSITION;
			float3 normal : NORMAL;
			float4 tangent : TANGENT;
			float2 uv : TEXCOORD0;
		};

		struct v2f
		{
			float4 vertex : SV_POSITION;
			float2 texUV : TEXCOORD0;
			float2 bumpUV : TEXCOORD1;
			float3 lightDir : TEXCOORD2;
			float3 viewDir : TEXCOORD3;
		};

		v2f vert (appdata v)
		{
			v2f o;
			o.vertex = UnityObjectToClipPos(v.vertex);
			
			o.texUV.xy = TRANSFORM_TEX(v.uv,_MainTex);
			o.bumpUV.xy = TRANSFORM_TEX(v.uv, _BumpMap);

			// TANGENT_SPACE_ROTATION 等于嵌入以下两行代码
			//float3 binormal = cross(v.normal, v.tangent.xyz) * v.tangent.w;
			//float3x3 rotation = float3x3(v.tangent.xyz, binormal, v.normal);
			TANGENT_SPACE_ROTATION;

			o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz;
			o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex)).xyz;

			return o;
		}
			
		fixed4 frag(v2f i) : SV_Target
		{
			float3 tangentLightDir = normalize(i.lightDir);
			float3 tangentViewDir = normalize(i.viewDir);
			float3 tangentNormal = UnpackNormal(tex2D(_BumpMap, i.bumpUV));
			tangentNormal.xy *= _BumpScale;
			// 单位向量已知xy, 求z而已
			tangentNormal.z = sqrt(1 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));

			float3 albedo = tex2D(_MainTex, i.texUV)*_Color.rgb;
			// 环境光
			fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz*albedo;
			// 漫反射
			fixed3 diffuse = _LightColor0.rgb*albedo*max(0, dot(tangentNormal, tangentLightDir));
			// 高光
			float3 halfViewLight = normalize(tangentViewDir+tangentLightDir);
			fixed3 specular = _LightColor0.rgb*_Specular*pow(max(0, dot(halfViewLight, tangentNormal)),_Gloss);
			return fixed4(ambient + diffuse + specular,1);
		}
		ENDCG
	}
	}
}
