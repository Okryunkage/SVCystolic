import tkinter as tk
from tkinter import messagebox
from PIL import Image, ImageDraw, ImageOps

CANVAS_SIZE = 280
MNIST_SIZE = 28
BRUSH_RADIUS = 10

MEM_FILENAME = "mnist_sample.mem"
PNG_FILENAME = "mnist_sample.png"
PREVIEW_FILENAME = "mnist_preview_28x28.png"


class DigitDrawer:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("MNIST Drawer -> .mem Export")

        self.canvas = tk.Canvas(
            root,
            width=CANVAS_SIZE,
            height=CANVAS_SIZE,
            bg="black",
            highlightthickness=1,
            highlightbackground="gray"
        )
        self.canvas.grid(row=0, column=0, columnspan=4, padx=10, pady=10)

        self.status_label = tk.Label(
            root,
            text="왼쪽 마우스로 숫자를 그린 뒤 Save MEM을 누르세요."
        )
        self.status_label.grid(row=1, column=0, columnspan=4, pady=(0, 10))

        self.clear_btn = tk.Button(root, text="Clear", width=12, command=self.clear)
        self.clear_btn.grid(row=2, column=0, padx=5, pady=5)

        self.save_mem_btn = tk.Button(root, text="Save MEM", width=12, command=self.save_mem)
        self.save_mem_btn.grid(row=2, column=1, padx=5, pady=5)

        self.save_png_btn = tk.Button(root, text="Save PNG", width=12, command=self.save_png)
        self.save_png_btn.grid(row=2, column=2, padx=5, pady=5)

        self.preview_btn = tk.Button(root, text="Preview 28x28", width=12, command=self.preview_28x28)
        self.preview_btn.grid(row=2, column=3, padx=5, pady=5)

        # 실제 이미지를 따로 유지
        self.image = Image.new("L", (CANVAS_SIZE, CANVAS_SIZE), 0)  # black background
        self.draw = ImageDraw.Draw(self.image)

        self.last_x = None
        self.last_y = None

        self.canvas.bind("<Button-1>", self.on_press)
        self.canvas.bind("<B1-Motion>", self.on_drag)
        self.canvas.bind("<ButtonRelease-1>", self.on_release)

    def clear(self):
        self.canvas.delete("all")
        self.image = Image.new("L", (CANVAS_SIZE, CANVAS_SIZE), 0)
        self.draw = ImageDraw.Draw(self.image)
        self.last_x = None
        self.last_y = None
        self.status_label.config(text="캔버스를 초기화했습니다.")

    def on_press(self, event):
        self.last_x = event.x
        self.last_y = event.y
        self._draw_point(event.x, event.y)

    def on_drag(self, event):
        if self.last_x is None or self.last_y is None:
            self.last_x = event.x
            self.last_y = event.y

        # 화면 표시
        self.canvas.create_line(
            self.last_x, self.last_y, event.x, event.y,
            fill="white",
            width=BRUSH_RADIUS * 2,
            capstyle=tk.ROUND,
            smooth=True
        )

        # 내부 이미지에도 동일하게 그림
        self.draw.line(
            [(self.last_x, self.last_y), (event.x, event.y)],
            fill=255,
            width=BRUSH_RADIUS * 2
        )
        self.draw.ellipse(
            (
                event.x - BRUSH_RADIUS, event.y - BRUSH_RADIUS,
                event.x + BRUSH_RADIUS, event.y + BRUSH_RADIUS
            ),
            fill=255
        )

        self.last_x = event.x
        self.last_y = event.y

    def on_release(self, _event):
        self.last_x = None
        self.last_y = None

    def _draw_point(self, x, y):
        self.canvas.create_oval(
            x - BRUSH_RADIUS, y - BRUSH_RADIUS,
            x + BRUSH_RADIUS, y + BRUSH_RADIUS,
            fill="white", outline="white"
        )
        self.draw.ellipse(
            (
                x - BRUSH_RADIUS, y - BRUSH_RADIUS,
                x + BRUSH_RADIUS, y + BRUSH_RADIUS
            ),
            fill=255
        )

    def get_mnist_image(self):
        # 단순 전체 resize
        mnist_img = self.image.resize((MNIST_SIZE, MNIST_SIZE), Image.Resampling.BILINEAR)
        return mnist_img

    def save_png(self):
        self.image.save(PNG_FILENAME)
        self.status_label.config(text=f"{PNG_FILENAME} 저장 완료")
        messagebox.showinfo("Saved", f"{PNG_FILENAME} 저장 완료")

    def preview_28x28(self):
        mnist_img = self.get_mnist_image()
        # 보기 편하게 반전 없이 그대로 저장
        mnist_img.save(PREVIEW_FILENAME)
        self.status_label.config(text=f"{PREVIEW_FILENAME} 저장 완료")
        messagebox.showinfo("Preview Saved", f"{PREVIEW_FILENAME} 저장 완료")

    def save_mem(self):
        mnist_img = self.get_mnist_image()
        pixels = list(mnist_img.getdata())  # row-major, length = 784

        with open(MEM_FILENAME, "w", encoding="utf-8") as f:
            for p in pixels:
                f.write(f"{int(p):02x}\n")

        self.status_label.config(text=f"{MEM_FILENAME} 저장 완료 (784 lines)")
        messagebox.showinfo("Saved", f"{MEM_FILENAME} 저장 완료")


if __name__ == "__main__":
    root = tk.Tk()
    app = DigitDrawer(root)
    root.mainloop()