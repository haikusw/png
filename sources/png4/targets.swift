public 
protocol _PNGColor 
{
    static 
    func unpack(_ interleaved:[UInt8], of format:PNG.Format, standard:PNG.Standard) 
        -> [Self]
}
extension PNG 
{
    public 
    typealias Color = _PNGColor
}

extension PNG.Color
{
    private static 
    func map<C, A, T>(_ samples:C, _ constructor:(T, A) -> Self, _ transform:(A) -> T)
        -> [Self]
        where C:RandomAccessCollection, C.Element == A, A:FixedWidthInteger
    {
        samples.map
        {
            let v:A = .init(bigEndian: $0)
            return constructor(transform(v), v)
        }
    }
    private static 
    func map<C, A, T>(_ samples:C, _ constructor:((T, T)) -> Self, _ transform:(A) -> T)
        -> [Self]
        where C:RandomAccessCollection, C.Index == Int, C.Element == A, A:FixedWidthInteger
    {
        stride(from: samples.startIndex, to: samples.endIndex, by: 2).map
        {
            let v:A = .init(bigEndian: samples[$0     ])
            let a:A = .init(bigEndian: samples[$0 &+ 1])
            return constructor((transform(v), transform(a)))
        }
    }
    private static 
    func map<C, A, T>(_ samples:C, _ constructor:((T, T, T), (A, A, A)) -> Self, _ transform:(A) -> T)
        -> [Self]
        where C:RandomAccessCollection, C.Index == Int, C.Element == A, A:FixedWidthInteger
    {
        stride(from: samples.startIndex, to: samples.endIndex, by: 3).map
        {
            let r:A = .init(bigEndian: samples[$0     ])
            let g:A = .init(bigEndian: samples[$0 &+ 1])
            let b:A = .init(bigEndian: samples[$0 &+ 2])
            return constructor((transform(r), transform(g), transform(b)), (r, g, b))
        }
    }
    private static 
    func map<C, A, T>(_ samples:C, _ constructor:((T, T, T, T)) -> Self, _ transform:(A) -> T)
        -> [Self]
        where C:RandomAccessCollection, C.Index == Int, C.Element == A, A:FixedWidthInteger
    {
        stride(from: samples.startIndex, to: samples.endIndex, by: 4).map
        {
            let r:A = .init(bigEndian: samples[$0     ])
            let g:A = .init(bigEndian: samples[$0 &+ 1])
            let b:A = .init(bigEndian: samples[$0 &+ 2])
            let a:A = .init(bigEndian: samples[$0 &+ 3])
            return constructor((transform(r), transform(g), transform(b), transform(a)))
        }
    }
    private static 
    func map<C, A, T>(_ samples:C, _ dereference:(Int) -> (A, A, A, A), 
        _ constructor:((T, T, T, T)) -> Self, _ transform:(A) -> T)
        -> [Self]
        where C:RandomAccessCollection, C.Element == UInt8, A:FixedWidthInteger
    {
        samples.map
        {
            let (r, g, b, a):(A, A, A, A) = dereference(.init($0))
            return constructor((transform(r), transform(g), transform(b), transform(a)))
        }
    }
    
    private static 
    func quantum<T>(source:Int, destination _:T.Type) -> T 
        where T:FixedWidthInteger & UnsignedInteger 
    {
        T.max / (T.max >> (T.bitWidth - source))
    }
    
    private static 
    func map<A, T, F>(_ buffer:[UInt8], of _:A.Type, depth:Int, constructor:F,  
        map:(UnsafeBufferPointer<A>, F, (A) -> T) -> [Self])
        -> [Self]
        where A:FixedWidthInteger, T:FixedWidthInteger & UnsignedInteger
    {
        buffer.withUnsafeBytes 
        {
            let samples:UnsafeBufferPointer<A> = $0.bindMemory(to: A.self)
            if      T.bitWidth == depth 
            {
                return map(samples, constructor, T.init(_:))
            }
            else if T.bitWidth >  depth 
            {
                let quantum:T = Self.quantum(source: depth, destination: T.self)
                return map(samples, constructor)
                {
                    quantum &* .init($0)
                }
            }
            else 
            {
                let shift:Int = depth - T.bitWidth 
                return map(samples, constructor)
                {
                    .init($0 &>> shift)
                }
            }
        }
    }
    
    static 
    func unpack<A, T>(_ buffer:[UInt8], dereference:(Int) -> (A, A, A, A), 
        constructor:((T, T, T, T)) -> Self)
        -> [Self]
        where A:FixedWidthInteger, T:FixedWidthInteger & UnsignedInteger
    {
        buffer.withUnsafeBufferPointer
        {
            if      T.bitWidth == A.bitWidth 
            {
                return Self.map($0, dereference, constructor, T.init(_:))
            }
            else if T.bitWidth >  A.bitWidth 
            {
                let quantum:T = Self.quantum(source: A.bitWidth, destination: T.self)
                return Self.map($0, dereference, constructor)
                {
                    quantum &* .init($0)
                }
            }
            else 
            {
                let shift:Int = A.bitWidth - T.bitWidth 
                return Self.map($0, dereference, constructor)
                {
                    .init($0 &>> shift)
                }
            }
        }
    }
    
    static 
    func unpack<A, T>(_ buffer:[UInt8], of _:A.Type, depth:Int, constructor:(T, A) -> Self)
        -> [Self]
        where A:FixedWidthInteger, T:FixedWidthInteger & UnsignedInteger
    {
        withoutActuallyEscaping(constructor) 
        {
            Self.map(buffer, of: A.self, depth: depth, constructor: $0, map: Self.map(_:_:_:))
        }
    }
    static 
    func unpack<A, T>(_ buffer:[UInt8], of _:A.Type, depth:Int, constructor:((T, T)) -> Self)
        -> [Self]
        where A:FixedWidthInteger, T:FixedWidthInteger & UnsignedInteger
    {
        withoutActuallyEscaping(constructor) 
        {
            Self.map(buffer, of: A.self, depth: depth, constructor: $0, map: Self.map(_:_:_:))
        }
    }
    static 
    func unpack<A, T>(_ buffer:[UInt8], of _:A.Type, depth:Int, constructor:((T, T, T), (A, A, A)) -> Self)
        -> [Self]
        where A:FixedWidthInteger, T:FixedWidthInteger & UnsignedInteger
    {
        withoutActuallyEscaping(constructor) 
        {
            Self.map(buffer, of: A.self, depth: depth, constructor: $0, map: Self.map(_:_:_:))
        }
    }
    static 
    func unpack<A, T>(_ buffer:[UInt8], of _:A.Type, depth:Int, constructor:((T, T, T, T)) -> Self)
        -> [Self]
        where A:FixedWidthInteger, T:FixedWidthInteger & UnsignedInteger
    {
        withoutActuallyEscaping(constructor) 
        {
            Self.map(buffer, of: A.self, depth: depth, constructor: $0, map: Self.map(_:_:_:))
        }
    }
}

extension PNG 
{
    @usableFromInline
    @_specialize(where T == UInt8)
    @_specialize(where T == UInt16)
    @_specialize(where T == UInt32)
    @_specialize(where T == UInt64)
    @_specialize(where T == UInt)
    static
    func premultiply<T>(color:T, alpha:T) -> T where T:FixedWidthInteger & UnsignedInteger
    {
        // an overflow-safe way of computing p = (c * (a + 1)) >> p.bitWidth
        let (high, low):(T, T.Magnitude) = color.multipliedFullWidth(by: alpha)
        // divide by 255 using this one neat trick!1!!!
        // value /. 255 == (value + 128 + (value >> 8)) >> 8
        let carries:(Bool, Bool),
            part:T.Magnitude
        (part,  carries.0) =  low.addingReportingOverflow(high.magnitude)
                carries.1  = part.addingReportingOverflow(T.Magnitude.max >> 1 + 1).overflow
        return high + (carries.0 ? 1 : 0) + (carries.1 ? 1 : 0)
    }
    
    @frozen
    public
    struct RGBA<T>:Hashable where T:FixedWidthInteger & UnsignedInteger
    {
        /// The red component of this color.
        public
        var r:T
        /// The green component of this color.
        public
        var g:T
        /// The blue component of this color.
        public
        var b:T
        /// The alpha component of this color.
        public
        var a:T

        /// Creates an opaque grayscale color with all color components set to the given
        /// value sample, and the alpha component set to `T.max`.
        /// 
        /// *Specialized* for `T` types `UInt8`, `UInt16`, `UInt32`, UInt64,
        ///     and `UInt`.
        /// - Parameters:
        ///     - value: The value to initialize all color components to.
        @_specialize(where T == UInt8)
        @_specialize(where T == UInt16)
        @_specialize(where T == UInt32)
        @_specialize(where T == UInt64)
        @_specialize(where T == UInt)
        public
        init(_ value:T)
        {
            self.init(value, value, value, T.max)
        }

        /// Creates a grayscale color with all color components set to the given
        /// value sample, and the alpha component set to the given alpha sample.
        /// 
        /// *Specialized* for `T` types `UInt8`, `UInt16`, `UInt32`, UInt64,
        ///     and `UInt`.
        /// - Parameters:
        ///     - value: The value to initialize all color components to.
        ///     - alpha: The value to initialize the alpha component to.
        @_specialize(where T == UInt8)
        @_specialize(where T == UInt16)
        @_specialize(where T == UInt32)
        @_specialize(where T == UInt64)
        @_specialize(where T == UInt)
        public
        init(_ value:T, _ alpha:T)
        {
            self.init(value, value, value, alpha)
        }

        /// Creates an opaque color with the given color samples, and the alpha
        /// component set to `T.max`.
        /// 
        /// *Specialized* for `T` types `UInt8`, `UInt16`, `UInt32`, UInt64,
        ///     and `UInt`.
        /// - Parameters:
        ///     - red: The value to initialize the red component to.
        ///     - green: The value to initialize the green component to.
        ///     - blue: The value to initialize the blue component to.
        @_specialize(where T == UInt8)
        @_specialize(where T == UInt16)
        @_specialize(where T == UInt32)
        @_specialize(where T == UInt64)
        @_specialize(where T == UInt)
        public
        init(_ red:T, _ green:T, _ blue:T)
        {
            self.init(red, green, blue, T.max)
        }

        /// Creates an opaque color with the given color and alpha samples.
        /// 
        /// *Specialized* for `T` types `UInt8`, `UInt16`, `UInt32`, UInt64,
        ///     and `UInt`.
        /// - Parameters:
        ///     - red: The value to initialize the red component to.
        ///     - green: The value to initialize the green component to.
        ///     - blue: The value to initialize the blue component to.
        ///     - alpha: The value to initialize the alpha component to.
        @_specialize(where T == UInt8)
        @_specialize(where T == UInt16)
        @_specialize(where T == UInt32)
        @_specialize(where T == UInt64)
        @_specialize(where T == UInt)
        public
        init(_ red:T, _ green:T, _ blue:T, _ alpha:T)
        {
            self.r = red
            self.g = green
            self.b = blue
            self.a = alpha
        }
        
        /* init(_ va:VA<Component>)
        {
            self.init(va.v, va.a)
        } */

        /// The red, and alpha components of this color, stored as a grayscale-alpha
        /// color.
        /// 
        /// *Inlinable*.
        /* @inlinable
        public
        var va:VA<Component>
        {
            .init(self.r, self.a)
        } */

        /* /// Returns a copy of this color with the alpha component set to the given sample.
        /// - Parameters:
        ///     - a: An alpha sample.
        /// - Returns: This color with the alpha component set to the given sample.
        func withAlpha(_ a:Component) -> RGBA<Component>
        {
            return .init(self.r, self.g, self.b, a)
        }

        /// Returns a boolean value indicating whether the color components of this
        /// color are equal to the color components of the given color, ignoring
        /// the alpha components.
        /// - Parameters:
        ///     - other: Another color.
        /// - Returns: `true` if the red, green, and blue components of this color
        ///     and `other` are equal, `false` otherwise.
        func equals(opaque other:RGBA<Component>) -> Bool
        {
            return self.r == other.r && self.g == other.g && self.b == other.b
        } */
    }
}
extension PNG.RGBA:PNG.Color 
{
    public static 
    func unpack(_ interleaved:[UInt8], of format:PNG.Format, standard:PNG.Standard) 
        -> [Self] 
    {
        switch standard 
        {
        case .common:   return Self.unpack(rgba: interleaved, of: format)
        case .ios:      return Self.unpack(bgra: interleaved, of: format)
        }
    }
    public static 
    func unpack(rgba interleaved:[UInt8], of format:PNG.Format) 
        -> [Self] 
    {
        let depth:Int = format.pixel.sampleDepth 
        switch format 
        {
        case    .indexed1(palette: let palette, background: _), 
                .indexed2(palette: let palette, background: _), 
                .indexed4(palette: let palette, background: _), 
                .indexed8(palette: let palette, background: _):
            return Self.unpack(interleaved) 
            {
                (i) in palette[i]
            }
            constructor:
            {
                (c) in .init(c.0, c.1, c.2, c.3)
            }
                
        case    .v1(background: _, key: nil),
                .v2(background: _, key: nil),
                .v4(background: _, key: nil),
                .v8(background: _, key: nil):
            return Self.unpack(interleaved, of: UInt8.self, depth: depth) 
            {
                (c:T, _) in .init(c)
            }
        case    .v16(background: _, key: nil):
            return Self.unpack(interleaved, of: UInt16.self, depth: depth) 
            {
                (c:T, _) in .init(c)
            }
        case    .v1(background: _, key: let key?),
                .v2(background: _, key: let key?),
                .v4(background: _, key: let key?),
                .v8(background: _, key: let key?):
            return Self.unpack(interleaved, of: UInt8.self, depth: depth)
            {
                (c:T, k:UInt8 )     in .init(c, k == key ? .min : .max)
            }
        case    .v16(background: _, key: let key?):
            return Self.unpack(interleaved, of: UInt16.self, depth: depth) 
            {
                (c:T, k:UInt16)     in .init(c, k == key ? .min : .max)
            }

        case    .va8(background: _):
            return Self.unpack(interleaved, of: UInt8.self, depth: depth)
            {
                (c:(T, T))          in .init(c.0, c.1)
            }
        case    .va16(background: _):
            return Self.unpack(interleaved, of: UInt16.self, depth: depth)
            {
                (c:(T, T))          in .init(c.0, c.1)
            }
        
        case    .rgb8(palette: _, background: _, key: nil):
            return Self.unpack(interleaved, of: UInt8.self, depth: depth)
            {
                (c:(T, T, T), _)    in .init(c.0, c.1, c.2)
            }
        case    .rgb16(palette: _, background: _, key: nil):
            return Self.unpack(interleaved, of: UInt16.self, depth: depth)
            {
                (c:(T, T, T), _)    in .init(c.0, c.1, c.2)
            }
        case    .rgb8(palette: _, background: _, key: let key?):
            return Self.unpack(interleaved, of: UInt8.self, depth: depth)
            {
                (c:(T, T, T), k:(UInt8,  UInt8,  UInt8 )) in 
                .init(c.0, c.1, c.2, k == key ? .min : .max)
            }
        case    .rgb16(palette: _, background: _, key: let key?):
            return Self.unpack(interleaved, of: UInt16.self, depth: depth)
            {
                (c:(T, T, T), k:(UInt16, UInt16, UInt16)) in 
                .init(c.0, c.1, c.2, k == key ? .min : .max)
            }
        
        case    .rgba8(palette: _, background: _):
            return Self.unpack(interleaved, of: UInt8.self, depth: depth)
            {
                (c:(T, T, T, T)) in .init(c.0, c.1, c.2, c.3)
            }
        case    .rgba16(palette: _, background: _):
            return Self.unpack(interleaved, of: UInt16.self, depth: depth)
            {
                (c:(T, T, T, T)) in .init(c.0, c.1, c.2, c.3)
            }
        }
    }
    public static 
    func unpack(bgra interleaved:[UInt8], of format:PNG.Format) 
        -> [Self] 
    {
        fatalError("unsupported")
    }
    
    @inlinable
    public
    var premultiplied:Self
    {
        .init(  PNG.premultiply(color: self.r, alpha: self.a),
                PNG.premultiply(color: self.g, alpha: self.a),
                PNG.premultiply(color: self.b, alpha: self.a),
                self.a)
    }
}

extension PNG.Data.Rectangular 
{
    public 
    func unpack<Color>(as _:Color.Type) -> [Color] where Color:PNG.Color
    {
        Color.unpack(self.storage, of: self.layout.format, standard: self.layout.standard)
    }
}
