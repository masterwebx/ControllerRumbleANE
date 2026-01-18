package com.masterwex.ane.rumble
{
    import flash.external.ExtensionContext;

    /**
     * Rumble ANE (Adobe Native Extension) for Adobe AIR
     *
     * Provides controller vibration support for Windows XInput-compatible controllers
     * (Xbox 360, Xbox One, Xbox Series X|S).
     *
     * This class serves as the ActionScript 3 interface to the native C++ implementation.
     * All methods are static and thread-safe for use across the AIR application.
     */
    public class Rumble
    {
        // Extension context for communicating with native code
        private static var _ctx:ExtensionContext;

        /**
         * Initialize the Rumble extension
         *
         * Must be called before using any other Rumble functions.
         * Enumerates connected controllers and prepares the native layer.
         *
         * @return Boolean - true if initialization successful, false otherwise
         */
        public static function initialize():Boolean
        {
            // Create extension context if not already created
            if (!_ctx)
            {
                // Extension ID must match the one in extension.xml
                _ctx = ExtensionContext.createExtensionContext("com.masterwex.ane.rumble", null);
                if (!_ctx)
                    return false; // Extension not available (not packaged or platform not supported)
            }

            // Call native initialize function
            var result:Object = _ctx.call("initialize");
            return Boolean(result);
        }

        /**
         * Set vibration on an XInput controller
         *
         * Controls the left and right vibration motors independently.
         * Duration is handled by the native layer with a detached thread.
         *
         * @param xinputIndex - XInput controller index (0-3)
         * @param left - Left motor intensity (0.0 = off, 1.0 = full)
         * @param right - Right motor intensity (0.0 = off, 1.0 = full)
         * @param durationMs - Duration in milliseconds (0 = continuous until stopped)
         * @return Boolean - true if command sent successfully, false otherwise
         */
        public static function setRumble(xinputIndex:int, left:Number, right:Number, durationMs:int):Boolean
        {
            // Ensure extension is initialized
            if (!_ctx)
                if (!initialize())
                    return false;

            // Call native setRumble function
            var result:Object = _ctx.call("setRumble", xinputIndex, left, right, durationMs);
            return Boolean(result);
        }

        /**
         * Get information about all active controllers
         *
         * Returns an array of active XInput controller indices.
         * Useful for debugging and controller enumeration.
         *
         * @return Array - Array of integers representing active controller indices, or null on error
         */
        public static function identifyActiveControllers():Array
        {
            // Ensure extension is initialized
            if (!_ctx)
            {
                if (!initialize())
                {
                    return null;
                }
            }

            // Call native identifyActiveControllers function
            var result:* = _ctx.call("identifyActiveControllers");

            // Return the array directly
            return (result is Array) ? result as Array : null;
        }

        /**
         * Get the current state of an XInput controller
         *
         * Returns button states and other input data for controller detection.
         *
         * @param xinputIndex - XInput controller index (0-3)
         * @return Object - Controller state with buttons field, or null if failed
         */
        public static function getControllerState(xinputIndex:int):Object
        {
            // Ensure extension is initialized
            if (!_ctx)
                if (!initialize())
                    return null;

            // Call native getControllerState function
            var result:Object = _ctx.call("getControllerState", xinputIndex);
            return result;
        }

        /**
         * Stop vibration on all controllers
         *
         * Immediately stops all vibration on all connected controllers.
         * Safe to call even if no controllers are vibrating.
         *
         * @return Boolean - true if command sent successfully, false otherwise
         */
        public static function stopAll():Boolean
        {
            // Ensure extension is initialized
            if (!_ctx)
                if (!initialize())
                    return false;

            // Call native stopAll function
            var result:Object = _ctx.call("stopAll");
            return Boolean(result);
        }

        /**
         * Shutdown the Rumble extension
         *
         * Stops all vibration and cleans up resources.
         * Should be called when the application is closing.
         *
         * @return Boolean - true if shutdown successful, false otherwise
         */
        public static function shutdown():Boolean
        {
            // Return true if already shut down
            if (!_ctx)
                return true;

            // Call native shutdown function
            var result:Object = _ctx.call("shutdown");

            // Dispose of extension context
            try
            {
                _ctx.dispose();
            }
            catch (e:Error)
            {
                // Ignore disposal errors
            }

            // Clear context reference
            _ctx = null;
            return Boolean(result);
        }
    }
}
