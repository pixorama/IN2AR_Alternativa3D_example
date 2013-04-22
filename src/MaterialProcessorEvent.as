package  
{
	import flash.events.Event;
	
	/**
	 * ...
	 * @author Pixorama
	 */
	public class MaterialProcessorEvent extends Event 
	{
		public static const ON_TEXTURES_SETUP_FINISHED:String = "on_textures_setup_finished";
		
		public function MaterialProcessorEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
		{ 
			super(type, bubbles, cancelable);
			
		} 
		
		public override function clone():Event 
		{ 
			return new MaterialProcessorEvent(type, bubbles, cancelable);
		} 
		
		public override function toString():String 
		{ 
			return formatToString("MaterialProcessorEvent", "type", "bubbles", "cancelable", "eventPhase"); 
		}
		
	}
	
}