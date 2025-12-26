# Treverse Engine
The open canvas for immersive interaction with Markdwn documents and interactive stories.
- [What's it do?](#about-treverse)
- [What's Markdown?](#what-is-markdown)
- [How do I use this beast?](#how-to-use-treverse)

<!-- `🅢 {left:53px;top:34px;width:246px;height:171px;}` -->

## About Treverse
Treverse parses Markdown documents into sections and renders them in a large interactive canvas. Users can navigate the documents by clicking local links or via the `Contents` section in the `Info` panel.
- [What's this Markdown?](#what-is-markdown)
- [How do I use Treverse?](#how-to-use-treverse)

<!-- `🅢 {left:196px;top:297.8000183105469px;width:326px;height:200px;}` -->

## What is Markdown
Markdown is a simple, plain text language sort of like BBCode. It lets you create documents quickly using basic symbols.
- [How do I use Treverse?](#how-to-use-treverse)

<!-- `🅢 {left:505px;top:128px;width:400px;height:200px;}` -->

## How to use Treverse
It's easy. Create a file at GitHub Gist, get the file's ID then paste it in the Gist field in the Info panel.
- [Cool, take me back to the start.](#treverse-engine)

<!-- `🅢 {left:700px;top:300px;width:400px;height:200px;}` -->

# Treverse `🅑-nav`

Interactive document immersion

`ⓘ The code below designates a list of content sources the user will be able to select from in the app.`

content `🅑-datalist`
- [Await](https://gist.github.com/eb48e3ccd0e0fc6a502a8ebe02a38715) - Simple example via monotony.
- [Psalm 13](https://gist.github.com/Ugotsta/5465780977626af6357811344774f003) - For lyrics mode (heading=p).

## Appearance `🅑-collapsible`

css `🅑-datalist`
- [Dark Glow](https://gist.github.com/c6d0a4d16b627d72563b43b60a164c31)

`🅑-theme-variables`

## Effects `🅑-collapsible`

vignette-blend `🅑-select`

vignette `🅑-slider="0.25,0,1,0.025"`

svg-filter `🅑-select`
- *None

---

brightness `🅑-slider="1,0,3,0.05"`
contrast `🅑-slider="100%,0,300,1,%"`
grayscale `🅑-slider="0%,0,100,1,%"`
hue-rotate `🅑-slider="0deg,0,360,1,deg"`
invert `🅑-slider="0%,0,100,1,%"`
saturate `🅑-slider="100%,0,300,1,%"`
sepia `🅑-slider="0%,0,100,1,%"`
blur `🅑-slider="0px,0,20,1,px"`

## Perspective `🅑-collapsible`

scale `🅑-slider="0,1,5,0.1"`
perspective `🅑-slider="1500px,0,2000,1,px"`
originx `🅑-slider="50%,0,100,1,%"`
originy `🅑-slider="50%,0,100,1,%"`
rotatex `🅑-slider="0deg,0,360,1,deg"`
rotatey `🅑-slider="0deg,0,360,1,deg"`
scalez `🅑-slider="0,1,5,0.1"`
rotatez `🅑-slider="0deg,0,360,1,deg"`
translatez `🅑-slider="0px,-500,500,1,px"`

## Dimensions `🅑-collapsible`

width `🅑-slider="960px,4,4000,1,px"`
height `🅑-slider="400px,4,2000,1,px"`
padding `🅑-slider="10px,0,500,1,px"`
inner-space `🅑-slider="100px,0,300,1,px"`
outer-space `🅑-slider="0px,0,300,1,px"`
offsetx `🅑-slider="0px,-4000,4000,1,px"`
offsety `🅑-slider="0px,-4000,4000,1,px"`

## Contents `🅑-collapsible`

`🅑-toc`

## Help `🅑-group`

`🅑-help`
`🅑-hide`