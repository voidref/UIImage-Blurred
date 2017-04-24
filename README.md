# UIImage-Blurred
Sometimes you need a blurry image, in swift, with cropping

Usage is hopefully self explanatory:

1. Start with your original image
2. Call `blurredImage` on it
  * at: Blur Radius - experiment with what looks best for you
  * tint: This color will just be drawn over the image, use an alpha value or you won't be too happy with the result
  * from: A rect that you can use to just grab a small area of the image to blur, if that's your thing.
  
