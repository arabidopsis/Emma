# import ArgParse: ArgParseSettings, @add_arg_table!, parse_args
import Logging
using ArgMacros

MayBeString = Union{Nothing,String}

# function emma_args(args::Vector{String}=ARGS)
#     emma_args = ArgParseSettings(prog="emma", autofix_names=true)

#     @add_arg_table! emma_args begin
#         "--level", "-l"
#         arg_type = String
#         default = "info"
#         help = "log level (info,warn,error,debug)"
#         "--transl-table"
#         arg_type = Int
#         default = 2
#         help = "NCBI translation table; 2 for vertebrates (the default), 5 for invertebrates"
#         "--rotate"
#         arg_type = String
#         help = "rotate genome and annotations to start with this feature"
#         "--gff"
#         arg_type = String
#         help = "output gff file"
#         "--fa"
#         arg_type = String
#         help = "output FASTA file (only makes sense with --rotate)"
#         "--svg"
#         arg_type = String
#         help = "output SVG image"
#         "--tbl"
#         arg_type = String
#         help = "output GB file"
#         "--tempdir", "-t"
#         arg_type = String
#         help = "directory to use for temporary files [default is current directory]"
#         "fastafiles"
#         arg_type = Stringusing ArgMacros
#         nargs = '+'
#         action = :store_arg
#         help = "fasta files to process"
#     end

#     emma_args.epilog = """
#     If there are multiple FASTA files then (--gff|--fa|--svg|--gb)
#     can refer to a directory using ArgMacrosin which case the respective files will be
#     placed there under the original filename (with new extension). Otherwise
#     the values will be used as a suffix.
#     """
#     parse_args(args, emma_args; as_symbols=true)
# end



function get_args()
    args = @dictarguments begin
        @helpusage "Emma/src/command.jl [options] <FASTA_file>"
        @helpdescription """
            Note: Use consistant inputs/outputs. If you wish
            to annotate a directory of fasta files, ensure that
            the output parameters are also directories.
            """
        @argumentdefault Int16 2 translation_table "--transl_table"
        @arghelp "NCBI translation table; 2 for vertebrates (the default), 5 for invertebrates"
        @argumentoptional String rotate_to "--rotate"
        @arghelp "rotate genome and annotations to start with this feature"
        @argumentoptional String FA_out "--fa"
        @arghelp "file/dir for fasta output"
        @argumentoptional String GFF_out "--gff"
        @arghelp "file/dir for gff output"
        @argumentoptional String GB_out "--tbl"
        @arghelp "file/dir for .tbl output (for GenBank submissions)"
        @argumentoptional String SVG_out "--svg"
        @arghelp "file/dir for svg output"
        @argumentdefault String "info" loglevel "--loglevel"
        @arghelp "loglevel (info,warn,error,debug)"
        @argumentdefault String "." tempdir "--tempdir"
        # @positionalrequired String FASTA_file
        @positionalleftover String FASTA_files "fastafiles"
        @arghelp "files/directories for fasta input"
    end
    args
end
const LOGLEVELS = Dict("info" => Logging.Info, "debug" => Logging.Debug, "warn" => Logging.Warn,
    "error" => Logging.Error)

function main()
    args = get_args()
    llevel = get(LOGLEVELS, lowercase(args[:loglevel]), Logging.Warn)
    global_logger(ConsoleLogger(stderr, llevel, meta_formatter=Logging.default_metafmt))

    function getout(accession, out, ext)
        if out === nothing
            return nothing
        end
        if isdir(out)
            return joinpath(out, basename(accession) * ext)
        end
        return accession * out
    end
    function getout1(accession, out, ext)
        if out === nothing
            return nothing
        end
        if isdir(out)
            return joinpath(out, basename(accession) * ext)
        end
        return out
    end

    fastafiles = args[:FASTA_files]
    function readfiles(d)
        if isdir(d)
            return filter(x -> endswith(x, ".fa") || endswith(x, ".fasta"), readdir(d, join=true))
        end
        [d]
    end
    fastafiles = [fa for d in fastafiles for fa in readfiles(d)]
    if length(fastafiles) != 1
        ofunc = getout
    else
        ofunc = getout1
    end
    for fasta in fastafiles
        accession = first(splitext(fasta))

        outfile_gff = ofunc(accession, args[:GFF_out], ".gff")
        outfile_fa = ofunc(accession, args[:FA_out], ".fa")
        outfile_svg = ofunc(accession, args[:SVG_out], ".svg")
        outfile_gb = ofunc(accession, args[:GB_out], ".tbl")
        try
            emma(fasta; translation_table=args[:translation_table], rotate_to=args[:rotate_to],
                outfile_gff=outfile_gff, outfile_gb=outfile_gb, outfile_fa=outfile_fa, outfile_svg=outfile_svg, tempdir=args[:tempdir])
        catch e
            @error "$(accession): $e"
        end
    end


end
