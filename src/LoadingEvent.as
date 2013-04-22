package  
{
	import flash.events.Event;
	
	/**
	 * ...
	 * @author Pixorama
	 */
	public class LoadingEvent extends Event 
	{
		public static const ON_TEXTURES_LOADING_FINISHED:String = "on_textures_loading_finished";
		
		public function LoadingEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
		{ 
			super(type, bubbles, cancelable);
			
		} 
		
		public override function clone():Event 
		{ 
			return new LoadingEvent(type, bubbles, cancelable);
		} 
		
		public override function toString():String 
		{ 
			return formatToString("LoadingEvent", "type", "bubbles", "cancelable", "eventPhase"); 
		}
		
	}
	
}