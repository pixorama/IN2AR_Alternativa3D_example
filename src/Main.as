package
{
	import alternativa.engine3d.animation.AnimationClip;
	import alternativa.engine3d.animation.AnimationController;
	import alternativa.engine3d.animation.AnimationSwitcher;
	import alternativa.engine3d.core.Camera3D;
	import alternativa.engine3d.core.Object3D;
	import alternativa.engine3d.core.Resource;
	import alternativa.engine3d.core.View;
	import alternativa.engine3d.lights.AmbientLight;
	import alternativa.engine3d.loaders.ParserA3D;
	import alternativa.engine3d.loaders.ParserCollada;
	import alternativa.engine3d.resources.ExternalTextureResource;
	import com.in2ar.calibration.IntrinsicParameters;
	import com.in2ar.IN2AR;
	import flash.display.Bitmap;
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.display.Stage3D;
	import flash.display.StageAlign;
	import flash.display.StageQuality;
	import flash.display.StageScaleMode;
	import flash.display.BitmapData;
	import flash.events.Event;
	import flash.geom.Matrix3D;
	import flash.geom.Point;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.system.ApplicationDomain;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import com.in2ar.calibration.IntrinsicParameters;
	import com.in2ar.detect.IN2ARReference;
	import com.in2ar.event.IN2ARDetectionEvent;
	
	/**
	 * ...
	 * @author Pixorama
	 */
	
	public class Main extends IN2ARBase
	{
		private const RESOURCE_LIMIT_ERROR_ID:int = 3691;
		private var camera:Camera3D;
		private var stage3D:Stage3D;
		private var view:View;
		private var scene:Object3D;
		private var arContainer:Object3D;
		private var modelContainer:Object3D;
		private var modelLoader:URLLoader;
		private var texturesList:Object = new Object();
		private var texturesCount:int = 0;
		private var parser:ParserCollada = new ParserCollada();
		private var materialProcessor:MaterialProcessor;
		private var texturesNameList:Array = new Array();
		private var ambientLight:AmbientLight = new AmbientLight(0xFFFFFF);
		
		private var cam:Camera;
		private var vid:Video;
		private var videoLayer:Bitmap;
		
		[Embed(source='../assets/def_data.ass',mimeType='application/octet-stream')]
		private static const DefinitionaData:Class;
		
		public var intrinsic:IntrinsicParameters;
		public var maxPoints:int = 300; // max points to allow to detect
		public var maxReferences:int = 1; // max objects will be used
		public var maxTrackIterations:int = 5; // track iterations
		
		public var camWidth:int = 640;
		public var camHeight:int = 480;
		public var downScaleRatio:Number = 1;
		public var srcWidth:int = 640;
		public var srcHeight:int = 480;
		public var mirror:Boolean = true;
		
		private var texturesPath:String = "models/";
		private var modelPath:String = "models/pug.DAE";
		
		private var in2ar:IN2AR;
		
		public function Main()
		{
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.stageFocusRect = false;
			stage.quality = StageQuality.BEST;
			addEventListener(Event.INIT, initAR);
			super();
		}
		
		private function initAR(e:Event = null):void
		{
			in2arLib.init(640, 480, maxPoints, maxReferences, 100, stage);
			in2arLib.setupIndexing(12, 10, true);
			in2arLib.setUseLSHDictionary(true);
			in2arLib.addReferenceObject(ByteArray(new DefinitionaData));
			in2arLib.setMaxReferencesPerFrame(1);
			
			intrinsic = in2arLib.getIntrinsicParams();
			
			in2arLib.addListener(IN2ARDetectionEvent.DETECTED, onModelDetected);
			in2arLib.addListener(IN2ARDetectionEvent.FAILED, onDetectionFailed);
			initCamera();
			init3D();
		}
		
		private function onModelDetected(e:IN2ARDetectionEvent):void
		{
			var refList:Vector.<IN2ARReference> = e.detectedReferences;
			var ref:IN2ARReference;
			var n:int = e.detectedReferencesCount;
			var state:String;
			
			for (var i:int = 0; i < n; ++i)
			{
				ref = refList[i];
				state = ref.detectType;
				var R:Vector.<Number> = ref.rotationMatrix;
				var t:Vector.<Number> = ref.translationVector;
				var mat:Matrix3D = new Matrix3D(new <Number>[+R[0], +R[3], +R[6], 0, -R[1], -R[4], -R[7], 0, -R[2], -R[5], -R[8], 0, +t[0], +t[1], +t[2], 1]);
				arContainer.matrix = mat;
				modelContainer.visible = true;
			}
		}
		
		private function onDetectionFailed(e:IN2ARDetectionEvent):void
		{
		
		}
		
		private function init3D():void
		{
			videoLayer = new Bitmap();
			addChild(videoLayer);
			
			camera = new Camera3D(1, 10000);
			camera.fov = 2 * Math.atan2(Math.sqrt(640 * 640 + 480 * 480), intrinsic.fx + intrinsic.fy);
			
			view = new View(640, 480, true, 0, 0, 4);
			view.hideLogo();
			camera.view = view;
			addChild(camera.view);
			addChild(camera.diagram);
			
			scene = new Object3D();
			scene.addChild(camera);
			
			arContainer = new Object3D();
			modelContainer = new Object3D();
			modelContainer.z = 150;
			modelContainer.scaleX = 25;
			modelContainer.scaleY = 25;
			modelContainer.scaleZ = 25;
			modelContainer.visible = false;
			
			arContainer.addChild(modelContainer);
			scene.addChild(arContainer);
			
			scene.addChild(ambientLight);
			
			stage3D = stage.stage3Ds[0];
			stage3D.addEventListener(Event.CONTEXT3D_CREATE, onContextCreate);
			stage3D.requestContext3D();
		}
		
		private function onContextCreate(evt:Event):void
		{
			for each (var resource:Resource in scene.getResources(true))
			{
				resource.upload(stage3D.context3D);
			}
			loadModel();
			addEventListener(Event.ENTER_FRAME, onEnterFrame);
		}
		
		private function loadModel():void
		{
			modelLoader = new URLLoader();
			modelLoader.dataFormat = URLLoaderDataFormat.TEXT;
			modelLoader.addEventListener(Event.COMPLETE, onModelLoaded);
			modelLoader.load(new URLRequest(modelPath));
		}
		
		private function onModelLoaded(evt:Event):void
		{
			setupModel(new XML(evt.target.data));
		}
		
		private function setupModel(model:XML):void
		{
			parser.parse(model);
			var hierarchyLength:uint = parser.hierarchy.length;
			for (var ind:uint = 0; ind < hierarchyLength; ind++)
			{
				modelContainer.addChild(parser.hierarchy[ind]);
			}
			
			for each (var textureResource:ExternalTextureResource in modelContainer.getResources(true, ExternalTextureResource))
			{
				var textureName:String = getShortTextureName(textureResource.url).toLocaleLowerCase();
				texturesNameList.push(textureName);
				var textureLoader:Loader = new Loader();
				textureLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoadingTextureComplete);
				texturesList[textureName] = textureLoader;
				texturesCount++;
			}
			
			for (var cnt1:int = 0; cnt1 < texturesNameList.length; cnt1++)
			{
				for (var cnt2:int = 0; cnt2 < texturesNameList.length; cnt2++)
				{
					if (cnt1 != cnt2)
					{
						if (texturesNameList[cnt1] == texturesNameList[cnt2])
						{
							texturesNameList[cnt1] = "";
							texturesCount--;
							
						}
					}
				}
			}
			addEventListener(LoadingEvent.ON_TEXTURES_LOADING_FINISHED, onTexturesLoaded);
			startTextureLoading();
		}
		
		private function onTexturesLoaded(evt:LoadingEvent):void
		{
			materialProcessor = new MaterialProcessor(stage3D.context3D);
			materialProcessor.addEventListener(MaterialProcessorEvent.ON_TEXTURES_SETUP_FINISHED, onTexturesSetupFinished);
			materialProcessor.setupMaterials(parser.objects);
		}
		
		private function onTexturesSetupFinished(evt:Event):void
		{
			for each (var textureResource:ExternalTextureResource in modelContainer.getResources(true, ExternalTextureResource))
			{
				var textureName:String = getShortTextureName(textureResource.url).toLocaleLowerCase();
				var isATFTexture:Boolean = textureName.split(".").pop() == "atf";
				try
				{
					materialProcessor.setupExternalTexture(textureResource, texturesList[textureName].content, isATFTexture);
				}
				catch (error:Error)
				{
					if (error.errorID == RESOURCE_LIMIT_ERROR_ID)
					{
						break;
					}
					else
					{
						throw error;
					}
				}
			}
			for each (var resource:Resource in modelContainer.getResources(true))
			{
				resource.upload(stage3D.context3D);
			}
			
			modelContainer.z = 30;
			
			addEventListener(Event.ENTER_FRAME, onEnterFrame);
		}
		
		private function startTextureLoading():void
		{
			for each (var textureResource:ExternalTextureResource in modelContainer.getResources(true, ExternalTextureResource))
			{
				var textureName:String = getShortTextureName(textureResource.url).toLocaleLowerCase();
				texturesList[textureName].load(new URLRequest(texturesPath + textureName));
			}
		}
		
		private function onLoadingTextureComplete(evt:Event):void
		{
			texturesCount--;
			if (texturesCount == 0)
			{
				var event:LoadingEvent = new LoadingEvent(LoadingEvent.ON_TEXTURES_LOADING_FINISHED);
				dispatchEvent(event);
			}
		}
		
		private function getShortTextureName(name:String):String
		{
			var shortName:String = name.split("/").pop();
			shortName = shortName.split("\\").pop();
			return shortName;
		}
		
		private function updateVideo():void
		{
			videoLayer.bitmapData = new BitmapData(640, 480);
			videoLayer.bitmapData.draw(vid);
			in2arLib.detect(videoLayer.bitmapData);
		}
		
		protected function initCamera(w:int = 640, h:int = 480, fps:int = 25):void
		{
			cam = Camera.getCamera();
			cam.setMode(w, h, fps);
			vid = new Video(w, h);
			vid.attachCamera(cam);
		}
		
		private function onEnterFrame(e:Event):void
		{
			camera.render(stage3D);
			updateVideo();
		}
	}

}