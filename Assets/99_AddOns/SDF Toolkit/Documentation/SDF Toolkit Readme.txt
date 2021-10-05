Copyright 2015, Catlike Coding
http://catlikecoding.com

This is Catlike Coding's SDF Toolkit. There is both a free and a complete version. It consists of two parts.

1: A Texture Generator, which provides a Unity editor window and an API to generate SDF textures from contour textures.
You can try out the generator with the included example contours.
See the "SDF Texture Generator" PDF for documentation.
The texture generator is part of the free toolkit.

2: A Collection of Shaders to render shapes using SDF textures.
For the built-in render pipeline, there is an unlit shader and shaders based on Unity's Standard shaders, for both metallic and specular workflows.
There is also a unitypackage archive containing a lit and an unlit shader graph that both work with URP and HDRP versions 10.4.0+.
See the "SDF Shaders" PDF for documentation.
These shaders are not part of the free toolkit.

The complete toolkit can be found on the Unity Asset Store at http://u3d.as/fmp

The latest version of the documentation can be found online at http://catlikecoding.com/sdf-toolkit/docs/

For support, contact support@catlikecoding.com or try https://catlikecoding.com/jasper-flick/ for online chat.

The SDF Toolkit has been available on the Asset Store since April 2015.
Its precursor has been available online as Distance Map Generator since Februari 2012.

VERSION HISTORY

2.0.0 for Unity 2020.3
Upgrade Notice: The folder structure has changed. Remove the old folders before installing this one.
New: Added lit and unlit shader graphs that work for both URP and HDRP versions 10.4.0+.

1.2.0 for Unity 2018.4
New: Made UI shaders work with Rect Mask 2D in addition to the image-based Mask.

1.1.3
Fix: Removed usage of obsolete ColorPickerHDRConfig in Unity 2018.3.

1.1.2

Fix: A name clash in SDF.cginc caused compile errors for PS4.

1.1.1

Fix: SDF Standard now works with UNITY_SPECCUBE_BLENDING and UNITY_SPECCUBE_BOX_PROJECTION keywords in Unity 5.5.

1.1

New: Generated textures that are saved to a new file are automatically setup as uncompressed single channel.
Change: Switched to Unity 5.5 texture importer system.
Change: Support for Unity versions below 5.5 is dropped.
Change: Upgraded shaders to use unity_ObjectToWorld instead of _Object2World.
Change: Marked UIMaterialLink as obsolete. Keywords now work for clipped UI materials. Edit-time refresh is up to Unity.

1.0

Change: Support for Unity versions below 5.2 is dropped.
Change: Shaders now use lighting function signatures introduced in Unity 5.2, as the old ones are obsolete.
Change: Overall code cleanup.

Beta 1.2

Change: Emissive colors are now controlled with the HDR color widget introduced in Unity 5.1.
Change: Removed the four emissive UI shader properties from all lit shaders as they are no longer needed.

Beta 1.1.1

Fix: Got rid of harmless sprite import error.

Beta 1.1

New: UI versions of the SDF shaders, along with an example scene.
New: UIMaterialLink component, which makes clipped sprites work with shader keywords and enables WYSIWYG editing.
Fix: Forward Add passes had incorrect normals when using a bevel without a normal map.

Beta 1.0.2

Change: Removed all colliders from example scene as they aren't used.

Beta 1.0.1

Fix: Solved shader input layout error for DX11 which caused invisible materials, plus some small shader tweaks.

Beta 1.0

First public release.
