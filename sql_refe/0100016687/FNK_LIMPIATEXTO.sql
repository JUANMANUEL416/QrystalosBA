create or alter function dbo.FNK_LIMPIATEXTO(
    @text  varchar(max), 
    @regex varchar(100)
)
returns varchar(max)
as
begin
    declare 
        @replace   varchar(max), 
        @replaceTo varchar(max), 
        @fix       int 
   
    set @replace   = '������������䃈���������'
    set @replaceTo = 'naeiouaeiouaoaeiooaeiouc'

    set @replace   = '������䃈���������'
    set @replaceTo = '�����������������c'
    set @fix       = 1
    --set @text=UPPER(@text)
    -- Si la expresi�n regular no son solo n�meros entrar�, sino evitar� entrar ahorrando tiempo de proceso
    if replace(@regex,space(1),space(0))<>'0-9'
    begin
        -- Si no se asigno expresi�n regular, asignar� una por defecto
        if isnull(@regex,space(0))=space(0)
            set @regex = 'a-z 0-9'

        -- Si la expresi�n regular tiene � se quita de los replace: @regex like '%�%'
        if lower(@regex) like '%�%'
        begin
            set @replace   = replace(@replace  ,'�',space(0))
            set @replaceTo = replace(@replaceTo,'n',space(0))
        end
      
        -- Se agregan minusculas y mayusculas a los replace
        set @replace   = lower(@replace  )+upper(@replace  )
        set @replaceTo = lower(@replaceTo)+upper(@replaceTo)
      
        -- Limpia acentuaciones y tildes desde los replace; COLLATE CS -> Case Sensitive
        while @fix <= len(@replace)
        begin
            set @text = replace(@text collate Modern_Spanish_CS_AS, substring(@replace,@fix,1), substring(@replaceTo,@fix,1))
            set @fix += 1
        end
    end  --Cierre para cuando contiene caracteres

    -- Se configura expresi�n regular
    set @regex = stuff('%[^]%',4,0,@regex)
   
    /*20250407 OSOLANO-KRODRIGUEZ siendo un lunes 10:19 con un frio en medellin y calor en riohacha, 
    SE AGREGA COLLATION Modern_Spanish_CI_AS CMAICAO NO REGISTRABA LA LETRA �*/
    -- Se quitan todo lo que no este incluido en la expresi�n regular
    while patindex(@regex, @text collate Modern_Spanish_CI_AS ) > 0
	begin
		set @text = replace(@text, substring(@text,patindex(@regex, @text collate Modern_Spanish_CI_AS),1), space(0))
	end

    -- Se quitan espacios dobles: @text like '%  %'
    while @text like '%'+space(2)+'%'
	begin
		set @text = replace(@text, space(2), space(1))
	end
   
    -- Se quitan espacios sobrantes a los lados
    set @text = ltrim(rtrim(@text))

	return @text
end
