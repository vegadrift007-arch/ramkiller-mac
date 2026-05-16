import SwiftUI

public extension Binding where Value: SetAlgebra, Value.Element: Hashable {
    /// Toggles membership of `element` via a Bool binding.
    /// Use as: `Toggle("", isOn: $selectedIDs.contains(id))`
    func contains(_ element: Value.Element) -> Binding<Bool> {
        Binding<Bool>(
            get: { wrappedValue.contains(element) },
            set: { isOn in
                if isOn {
                    wrappedValue.insert(element)
                } else {
                    wrappedValue.remove(element)
                }
            }
        )
    }
}

public extension Binding where Value == Set<String> {
    /// "Select all" toggle for a Set<String> against a list of items' string IDs.
    /// Returns true iff the set contains every id in the list (and the list is non-empty).
    func selectAll<C: Collection>(of items: C) -> Binding<Bool> where C.Element == String {
        Binding<Bool>(
            get: { !items.isEmpty && items.allSatisfy { wrappedValue.contains($0) } },
            set: { isOn in
                wrappedValue = isOn ? Set(items) : []
            }
        )
    }
}
