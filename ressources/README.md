# navhandler 

# Background
When implementing PWAs as general UI the picture established itself that everything happens via navigation of UI states.
Herein especially important is the System Navigation (e.g. clicking the back button etc). For a good user experience we want to handle system navigation gracefully, such that a backbutton click results in a backwards navigation of the PWAs UI state etc.

Thus the navhandler was born. It deals with the history API of the browser, tells us when the PWAs UI state is to be updated and therefore we should use it as the source and sink of all UI state navigation.

# Usage
Current Functionality
---------------------
```coffescript
import * as  nav from "navhandler"

## first initialize the navhander
# - function to be called when the app is loaded
# - function to be called each further time when the NavState Changes
# - boolean to for debug-mode (optional)
nav.initialize(loadWithNavState, navStateUpdate, false)
## Note that `loadWithNavState` and `navStateUpdate` may have any name and you need to implement them! 

## Then you neeed to make sure `nav.appLoaded()` is called when the app is loaded
## e.g anything with a similar effect as:
document.addEventListener("DOMContentLoaded", nav.appLoaded); 


## Functions you need to implement - - - - -

## Implement our Functions according to the new Flow of things.
loadWithNavState = (navState) ->
    ## TODO implement actions on refresh or initial pageload 
    {base, modifier, context, depth, navAction} = navState
    ## from navAction we can tell if `navAction.action` is "pageLoad" or "browserNav {refresh, back or forward}"
    ## Anyways, at best load the App here as if it was the first start and consider that this could happen in any UI state
    return

navStateUpdate = (navState) ->
    ## TODO implement action on any navigation which has happened, navState is the new state
    {base, modifier, context, depth, navAction} = navState
    ## from navAction we can tell what has brought us here like `navAction.action` being "back" or "nav" or "browserNav {refresh, back or forward}"
    return
    
## Active Navigation - - - - -

## Navigating Base State (e.g. the user clicks a button to open a new "page")
# - string name of the base state
# - object with context information for this state
nav.toBase("page-x", context)
## this always increases the depth by 1


## If you don't want to increase depth, you can use this function and 
## specify a depth you want to end up in
nav.toBaseAt("page-x", context, 1)


## Navigating Modifiers
# - string name of the modifier state
# - object with context information for this state
nav.toMod(modifier, context)


## Backwards Navigation
# - number of steps to navigate back
nav.back(steps)

## Backwards Navigateion to the RootState
# - boolean if the history tree should be cleared
nav.toRoot(true)


```

---

# Base State vs Modifier State
We have 2 different types of UI state we deal with.
The `modifier` state and the `base` state. Both states are described by strings and are available in the `navState` object as `navState.base` and `navState.modifier`.
Mainly you set them by a name of your choosing, and if there is any navigation happening you get the update with the `navState` object in `navState.base` telling you which state it is.
There also is a `context` object. You may set arbitrary data in this object when you set it, you get the data on any update of the `navState` in `navState.context`.
A `modifier` state may overlap with a `base` state. If they do then their context object is merged into a single one.


## Base State
This is simlar to a new "page". You cannot be on 2 different "pages" simultanously.
So every navigation via `nav.toBase(base, ctx)` to a different base state adds a new navigation entry in the history stack.

You can also specify the depth where to add this navigation entry into the history stack by using `nav.toBaseAt(base, ctx, depth)`. This is useful when you don't want the default behaviour of a new entry to the history stack, e.g. if you have competing pages which are considered to be on the same navigation level.

Naturally, any navigation to a `base` state leads to the modifier being set to "none".

There 2 are reserved `base` states:

### `RootState`
The first Loaded `base` state is always the `RootState`. It always has `navState.depth = 0`. No other state may replace the `RootState`.
You may take it as the generic state for the "Homepage".

### `VOID`
The `VOID` `base` state never triggers an `navStateUpdate` call. It is used internally, to clear a the history branch.


## Modifier State
`modifier` states are to be added on top of a `base` state. This is for example, when a menu, or a popup is opened, overlaying the "page" but not changing the current `base` state.
When navigating to `modifier` states as with `nav.toMod(modifier, ctx)` the base state stays untouched the context is merged and if we were in any other `modifier` state that `modifier` state is simply replaced. (Don't try to overlay the current `base` state with 2+ different popups to be navigatable back in 2+ steps...^^)

We have one reserved modifier state.

### `none`
The `none` modifier is the default modifier when there are no modifiers active. This <s>cannot</s> shallnot be used for any other purposes.


# navState

The navState is the main information structure here and is passed to your `update` and `onLoad` functions.

This is an example structure:
```
{
    "base": "page2",
    "modifier": "none",
    "context": {
        "someCounter": "1"
    },
    "depth": 1,
    "navAction": {
        "action": "nav",
        "timestamp": 1706721511593
    }
}
```


# navAction
You could see that in the navState there is a member called `navAction`. It is imporant for recognizing how we have navigated to the current state and when we did so. It consists of an `action` and a `timestamp`.
```
    "navAction": {
        "action": "nav",
        "timestamp": 1706721511593
    }
```


If the timestamp does not match with our last known active navigation - then we deal with a browser nagivation. In this case the `navAction` is immediatly updated before passed to your `navStateUpdate`. (E.g. navitate to `page2` then press refresh in the browser.)
```
    "navAction": {
        "action": "browserNav {refresh, back or forward}",
        "timestamp": 1706721622505
    }
```

We have 4 discriminable navActions
- `nav` - regular forward navigation via `nav.toMod`, `nav.toBase`, or `nav.toBaseAt`
- `back` - any backwards navigation via `nav.back` or `nav.toRoot`
- `browserNav {refresh, back or forward}` - any browser navigation
- `pageload` - the first pageload

# Further steps

- Add more features when the requirement pops up.
- Fix bugs, as soon as the pop up.

All sorts of inputs are welcome, thanks!

---

# License
[Unlicense JhonnyJason style](https://hackmd.io/nCpLO3gxRlSmKVG3Zxy2hA?view)
