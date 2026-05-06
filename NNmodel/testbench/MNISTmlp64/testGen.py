import tkinter as tk
from tkinter import messagebox
from PIL import Image, ImageDraw, ImageOps

CANVAS_SIZE = 280
MNIST_SIZE = 28
BRUSH_RADIUS = 10

MEM_FILENAME ="mnist_sample.mem"
PNG_FILENAME ="mnist_sample.png"
PREVIEW_FILENAME ="mnist_preview_28x28.png"

class DigitDrawer:
	def __init__(self,root:tk.Tk):
		#Store the root Tkinter window in this object
		#So it can be accessed throughout the class.
		self.root =root
		self.root.title("MNIST Drawer -> .mem Export")
		#canvas window configuration
		self.canvas =tk.Canvas(
			root,
			width=CANVAS_SIZE,
			height=CANVAS_SIZE,
			bg="black",
			highlightthickness=1,
			highlightbackground="gray")
		#Place canvas at 0,0 grid
		self.canvas.grid(row=0,column=0,columnspan=4,padx=10,pady=10)
		#Label configuration
		self.status_label =tk.Label(root,text="Draw a number with the left mouse button, then press <saveMEM>.")
		self.status_label.grid(row=1,column=0,columnspan=4,pady=(0, 10))
		#Clear button Configuration
		self.clear_btn =tk.Button(root,text="Clear",width=12,command=self.clear)
		self.clear_btn.grid(row=2,column=0,padx=5,pady=5)
		#saveMEM button Configuration
		self.save_mem_btn =tk.Button(root,text="Save MEM",width=12,command=self.save_mem)
		self.save_mem_btn.grid(row=2,column=1,padx=5,pady=5)
		#savePNG button Configuration
		self.save_png_btn = tk.Button(root,text="Save PNG",width=12,command=self.save_png)
		self.save_png_btn.grid(row=2, column=2, padx=5, pady=5)
		#preview button Configuration
		self.preview_btn = tk.Button(root,text="Preview 28x28",width=12,command=self.preview_28x28)
		self.preview_btn.grid(row=2,column=3,padx=5,pady=5)
		#Create a new grayscale ("L") image.
		# - "L": single-channel grayscale image (pixel values from 0 to 255)
		# - (CANVAS_SIZE, CANVAS_SIZE): image width and height, e.g. 280x280
		# - 0: fill the entire image with black as the initial background
		#This PIL image is kept separately as the actual drawing data.
		self.image = Image.new("L",(CANVAS_SIZE,CANVAS_SIZE),0)
		#Create a drawing context for self.image.
		#This allows the program to draw lines, circles, and other shapes
		#directly onto the PIL image stored in self.image.
		self.draw = ImageDraw.Draw(self.image)
		#variable to save the last coordinate for drawing
		self.last_x = None
		self.last_y = None
		#bind left button to on_press on canvas
		self.canvas.bind("<Button-1>",self.on_press)
		#bind moving mouse while pressing leftbutton to on_drag on canvas
		self.canvas.bind("<B1-Motion>",self.on_drag)
		#bind releasing left button to on_release on canvas
		self.canvas.bind("<ButtonRelease-1>",self.on_release)

	def clear(self):
		self.canvas.delete("all")
		self.image =Image.new("L",(CANVAS_SIZE,CANVAS_SIZE),0)
		self.draw =ImageDraw.Draw(self.image)
		self.last_x =None
		self.last_y =None
		self.status_label.config(text="Initilized Canvas")

	#event is the Tkinter event object automatically passed in
	#when the mouse button is pressed.
	#event.x and event.y give the mouse position on the canvas.
	def on_press(self,event):
		self.last_x =event.x
		self.last_y =event.y
		#Call the internal helper method that draws a single point at the mouse click position.
		self._draw_point(event.x,event.y)

	def on_drag(self,event):
		if self.last_x is None or self.last_y is None:
			self.last_x =event.x
			self.last_y =event.y
		self.canvas.create_line(
			self.last_x,self.last_y,event.x,event.y,
			fill="white",
			width=BRUSH_RADIUS*2,
			capstyle=tk.ROUND,
			smooth=True)
		self.draw.line(
			[(self.last_x,self.last_y),(event.x,event.y)],
			fill=255,
			width=BRUSH_RADIUS*2)
		self.draw.ellipse(
			(event.x -BRUSH_RADIUS,event.y -BRUSH_RADIUS,
			 event.x +BRUSH_RADIUS,event.y +BRUSH_RADIUS),
            fill=255)
		self.last_x =event.x
		self.last_y =event.y

	#Tkinter still passes an event object to this callback,
	#but it is not used in this function, so it is named _event.
	def on_release(self,_event):
		self.last_x =None
		self.last_y =None

	#Create circle on the canvas
	def _draw_point(self,x,y):
		self.canvas.create_oval(
			x-BRUSH_RADIUS,y-BRUSH_RADIUS,
			x+BRUSH_RADIUS,y+BRUSH_RADIUS,
			fill="white",outline="white")
		self.draw.ellipse(
			(x-BRUSH_RADIUS,y-BRUSH_RADIUS,
			 x+BRUSH_RADIUS,y+BRUSH_RADIUS),
			fill=255)

	def get_mnist_image(self):
		#resize image to MNIST format(28X28)
		mnist_img = self.image.resize((MNIST_SIZE,MNIST_SIZE),Image.Resampling.BILINEAR)
		return mnist_img

	def save_png(self):
		self.image.save(PNG_FILENAME)
		self.status_label.config(text=f"{PNG_FILENAME} save completed")
		messagebox.showinfo("Saved",f"{PNG_FILENAME} save completed")

	def preview_28x28(self):
		mnist_img =self.get_mnist_image()
		#Save without inversion
		mnist_img.save(PREVIEW_FILENAME)
		self.status_label.config(text=f"{PREVIEW_FILENAME} completed")
		messagebox.showinfo("Preview Saved",f"{PREVIEW_FILENAME} completed")

	def save_mem(self):
		mnist_img =self.get_mnist_image()
		pixels =list(mnist_img.getdata())  # row-major, length = 784
		with open(MEM_FILENAME,"w",encoding="utf-8") as f:
			for p in pixels:
				f.write(f"{int(p):02x}\n")
		self.status_label.config(text=f"{MEM_FILENAME} save completed (784 lines)")
		messagebox.showinfo("Saved",f"{MEM_FILENAME} save completed")

if __name__ =="__main__":
	root =tk.Tk()
	app =DigitDrawer(root)
	root.mainloop()