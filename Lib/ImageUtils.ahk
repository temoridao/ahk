/**
 * Description:
 *    Contains functions to work with images, search images on the screen, etc.
 * License:
 *    Dedicated to Public Domain. See UNLICENSE.txt for details
*/

#include %A_LineFile%\..\CommonUtils.ahk
#include %A_LineFile%\..\MouseCursorPositionRestoreGuard.ahk

class ImageUtils extends StaticClassBase {
	/**
	 * Search for image on the screen and move cursor to its center if succeded
	 *
	 * This function is essentially a wrapper around `ImageSearch` command but provides more
	 * convenient interface and results/errors reporting as well as clicking on the found region.
	 *
	 * Note that client code must set `A_CoordModePixel` to desired value as described
	 * in `ImageSearch` command documentation or pass value in @p relativeTo parameter to allow this
	 * function to make this temporary change for you.
	 * @code{.ahk}
	   CoordMode, Pixel, Screen ;Perform search and click relative to screen coordinates,
	                            ;because A_CoordModePixel equals to "Window" by default

	   ; Search for "my_button.png" in top-left quadrant of primary screen and perform left click
	   ; on the found region's center
	   if (foundPos := ImageUtils.moveCursorToImageCenter("my_button.png", 0, 0, A_ScreenWidth/2, A_ScreenHeight/2, "", "1")) {
	   	MsgBox % "An image my_button.png found at position " foundPos.x "x" foundPos.y
	   } else {
	   	MsgBox % "An image my_button.png not found: " ErrorLevel
	   }
	 * @endcode
	 *
	 * @param   imgToSearch    The image to search
	 * @param   x1             Equivalent to `ImageSearch`'s X1 parameter (left)
	 * @param   y1             Equivalent to `ImageSearch`'s Y1 parameter (top)
	 * @param   x2             Equivalent to `ImageSearch`'s X2 parameter (right), except if omitted,
	 *                         the whole width of target area (according to `A_CoordModePixel`)
	 *                         will be used
	 * @param   y2             Equivalent to `ImageSearch`'s Y2 parameter (bottom), except if omitted,
	 *                         the whole height of target area (according to `A_CoordModePixel`)
	 *                         will be used
	 * @param   searchOptions  Identical to `ImageSearch`'s options passed in `ImageFile` parameter.
	 *                         Do not include trailing white-spaces because 1 space will be
	 *                         added by this function before appending @p imgToSearch to the value of
	 *                         this parameter (if not empty)
	 * @param   clickOptions   Identical to `Click`'s `Options` parameter. Do not include leading
	 *                         white-spaces because 1 space will be added by this function before
	 *                         appending this parameter to `Send {Click x y...}` in place of `...`
	 * @param   relativeTo     Specify reference coordinate system (`CoordMode`) for `ImageSearch`
	 *                         and `Click` commands. If omitted, defaults to
	 *                         current `A_CoordModePixel`
	 * @param   restoreCursorPos  Is mouse cursor must be moved to its initial position after click
	 *                            on image @p imgToSearch had performed?
	 *
	 * @return  If image was found, returns an object with `x` and `y` properties specifying its
	 *          coordinates relative to @p relativeTo. If nothing found or some error occured — an
	 *          empty value returned (additional info can be found in `ErrorLevel` as described in
	 *         `ImageSearch`'s documentation)
	 */
	moveCursorToImageCenter(imgToSearch, x1 := 0, y1 := 0, x2 := "fullWidth", y2 := "fullHeight", searchOptions := "", clickOptions := "0", relativeTo := "A_CoordModePixel", restoreCursorPos := false) {
		raiiCoordModePixel := {}
		if (relativeTo != "A_CoordModePixel") {
			raiiCoordModePixel := avarguard("A_CoordModePixel=" relativeTo)
		}

		hWnd := WinGet("ID", "A")
		if (x2 = "fullWidth") {
			if (A_CoordModePixel = "Window") {
				WinGetPos,,, winWidth,, ahk_id %hWnd%
				x2 := winWidth
			} else if (A_CoordModePixel = "Client") {
				CommonUtils.WinGetClientSize(clientWidth, clientHeight)
				x2 := clientWidth
			} else if (A_CoordModePixel = "Screen") {
				x2 := A_ScreenWidth
			} else {
				x2 := 0
			}
		}
		if (y2 = "fullHeight") {
			if (A_CoordModePixel = "Window") {
				WinGetPos,,,, winHeight, ahk_id %hWnd%
				y2 := winHeight
			} else if (A_CoordModePixel = "Client") {
				CommonUtils.WinGetClientSize(clientWidth, clientHeight)
				y2 := clientHeight
			} else if (A_CoordModePixel = "Screen") {
				y2 := A_ScreenHeight
			} else {
				y2 := 0
			}
		}

		so := searchOptions != "" ? (searchOptions " ") : ""
		ImageSearch, FoundX, FoundY, x1, y1, x2, y2, %  so . imgToSearch
		if (!ErrorLevel) {
			; logDebug("The icon {1} was found at {2}x{3} [A_CoordModePixel: {4}]", quote(imgToSearch), FoundX, FoundY, A_CoordModePixel)
			raiiCoordModeMouse := avarguard("A_CoordModeMouse=" A_CoordModePixel)
			imgSize := ImageUtils.imageSize(imgToSearch)
			centerX := FoundX + imgSize.width / 2
			centerY := FoundY + imgSize.height / 2
			mcrGuard := restoreCursorPos ? new MouseCursorPositionRestoreGuard : ""

			co := clickOptions != "" ? (" " clickOptions) : ""
			Send("{Click " CenterX " " CenterY co "}")
			return {x: FoundX, y: FoundY}
		}

		if (ErrorLevel = 2) {
			ErrorLevel := Format("Could not conduct the search ({:#X})", ErrorLevel)
		} else if (ErrorLevel = 1) {
			ErrorLevel := Format("Image could not be found on the {} ({:#X})", (A_CoordModePixel = "Screen" ? "screen" : ("active window " quote(WinGetTitle("ahk_id" hWnd)))), ErrorLevel)
		}
		return ""
	}

	/**
	 * Get image size in pixels
	 *
	 * @param   img  The image (can be a path, handle, .dll, .exe or other supported image
	 *               specification supported by AutoHotkey
	 *
	 * @return  An object with `width` and `height` properties
	 */
	imageSize(img) {
		Gui New
		Gui Add, picture, hWndhWnd, %img%
		ControlGetPos,,,width,height,,ahk_id %hWnd%
		Gui Destroy

		return {width: width, height: height}
	}

	/**
	 * Get full path of @p imageBaseName for this script's image resource directory
	 *
	 * @param   imageBaseName  The image filename under "img" directory
	 *
	 * @return  Full path to @p imageBaseName. F.e. for script C:\path\to\my\scripts\MyScript.ahk
	 *          and @p imageBaseName equal to `my.png` the result of this function will be
	 *          `C:\path\to\my\scripts\img\MyScript_my.png`
	 */
	imageResourcePath(imageBaseName) {
		return A_ScriptDir "\img\" scriptBaseName() "_" imageBaseName
	}
}