`pxg` is a utilities library for pixelgrade

Sample `pxg.json` file:

	{
		"wp-cores": [
			{
				"repo": "https://github.com/pixelgrade/pixcore.git",
				"path": "core",
				"version": "1.0.0",
				"namespace": {
					"src": "pixcore",
					"target": "myproj"
				}
			}
		]
	}

You would then use myproj to call library functions and have access to all
pixcore classes only under the `Myproj` prefix instead of the `Pixcore` prefix.
