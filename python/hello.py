#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import tkinter as tk
from tkinter import ttk
import sys

def close_window():
    """סוגר את החלון"""
    root.destroy()
    sys.exit()

# יצירת החלון הראשי
root = tk.Tk()
root.title("הודעת שלום")
root.geometry("300x150")
root.resizable(False, False)

# מרכוז החלון במסך
window_width = 300
window_height = 150
screen_width = root.winfo_screenwidth()
screen_height = root.winfo_screenheight()
x = (screen_width - window_width) // 2
y = (screen_height - window_height) // 2
root.geometry(f"{window_width}x{window_height}+{x}+{y}")

# עיצוב
root.configure(bg='#f0f0f0')

# תווית עם הודעת שלום
label = tk.Label(
    root, 
    text="שלום!", 
    font=("Arial", 24, "bold"),
    bg='#f0f0f0',
    fg='#2c3e50'
)
label.pack(pady=30)

# כפתור סגירה
close_button = ttk.Button(
    root,
    text="סגור",
    command=close_window,
    width=10
)
close_button.pack()

# סגירה אוטומטית אחרי 3 שניות (אופציונלי)
# אם תרצה שהחלון יסגר אוטומטית, הסר את הסימון מהשורה הבאה:
# root.after(3000, close_window)

# הרצת הלולאה הראשית
root.mainloop()
