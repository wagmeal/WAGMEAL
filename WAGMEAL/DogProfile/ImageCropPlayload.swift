// ImageCropPayload.swift
import UIKit

struct ImageCropPayload: Identifiable, Equatable {
    let id = UUID()
    let image: UIImage
}
